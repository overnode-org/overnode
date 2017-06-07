//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import play.api.libs.json.{JsObject, JsValue, Json}

import scala.util.Try
import scalaj.http.{Http, HttpRequest, HttpResponse}

object EtcdStore {
    // assuming that the process is terminated after dry run and the cache is cleared
    private var dryRunNodes = Map[String, NodeConfiguration]()
    private var dryRunServices = Map[Int, String]()
    private var dryRunIps = Map[String, IpAddressConfiguration]()
    private var dryRunApplyConfig: Option[ApplyConfiguration] = None

    def getNodeConfig(nodeUuid: String): Option[NodeConfiguration] = {
        dryRunNodes.get(nodeUuid).fold({
            val resp = call(Http(s"$etcdAddr/nodes/$nodeUuid"))
            if (resp.code == 200) {
                Some(NodeConfiguration.fromJson(unpack(resp.body)))
            } else if (resp.code == 404) {
                None
            } else {
                throw new EtcdException(s"failure to fetch configuration (${resp.code}): ${resp.body}")
            }
        }){f => Some(f)}
    }

    def setNodeConfig(config: NodeConfiguration, isDryRun: Boolean): NodeConfiguration = {
        boostrap()

        if (isDryRun) {
            dryRunNodes = dryRunNodes ++ Map(config.nodeUuid -> config)
        } else {
            val response = call(Http(s"$etcdAddr/nodes/${config.nodeUuid}")
                .params(Seq("value" -> Json.prettyPrint(config.toJson)))
                .put(Array.empty[Byte]))
            if (response.code < 200 || response.code > 299) {
                throw new EtcdException(s"failure to save node configuration (${response.code}): ${response.body}")
            }
        }
        config
    }

    def getApplyConfig: ApplyConfiguration = {
        dryRunApplyConfig.fold({
            val resp = call(Http(s"$etcdAddr/apply.json"))
            if (resp.code == 200) {
                ApplyConfiguration.fromJson(unpack(resp.body))
            } else if (resp.code == 404) {
                ApplyConfiguration.fromJson(Json.obj())
            } else {
                throw new EtcdException(s"failure to fetch configuration (${resp.code}): ${resp.body}")
            }
        }){f => f}
    }

    def setApplyConfig(config: ApplyConfiguration, isDryRun: Boolean): ApplyConfiguration = {
        if (isDryRun) {
            dryRunApplyConfig = Some(config)
        } else {
            val response = call(Http(s"$etcdAddr/apply.conf")
                .params(Seq("value" -> Json.prettyPrint(config.toJson)))
                .put(Array.empty[Byte]))
            if (response.code < 200 || response.code > 299) {
                throw new EtcdException(s"failure to save apply configuration (${response.code}): ${response.body}")
            }
        }
        config
    }

    def getIpAddressConfiguration(address: String): Option[IpAddressConfiguration] = {
        dryRunIps.get(address).fold({
            val resp = call(Http(s"$etcdAddr/ips/$address"))
            if (resp.code == 200) {
                Some(IpAddressConfiguration.fromJson(unpack(resp.body)))
            } else if (resp.code == 404) {
                None
            } else {
                throw new EtcdException(s"unexpected response code (${resp.code}): ${resp.body}")
            }
        }){f => Some(f)}
    }

    def getOrAllocateIpAddressConfiguration(serviceName: String, nodeId: String, isDryRun: Boolean): String = {
        val candidates = getServiceIds(serviceName).flatMap(i => subnetIdRange.map(j => i -> j))
        val maybeFound = candidates.find(c => {
            val candidate = IpAddressConfiguration.fromOffsets(c._1, c._2, serviceName, nodeId)
            getIpAddressConfiguration(candidate.address).fold(false){
                f => f.nodeUuid == nodeId && f.serviceName == serviceName
            }
        }).map(f => IpAddressConfiguration.fromOffsets(f._1, f._2, serviceName, nodeId).address)
        maybeFound.getOrElse(allocateIpAddressConfiguration(serviceName, nodeId, isDryRun))
    }

    def allocateIpAddressConfiguration(serviceName: String, nodeId: String, isDryRun: Boolean): String = {
        def allocateWithin(serviceIds: Seq[Int]) = {
            val candidates = serviceIds.flatMap(i => subnetIdRange.map(j => i -> j))
            candidates.find(c => {
                val candidate = IpAddressConfiguration.fromOffsets(c._1, c._2, serviceName, nodeId)
                if (isDryRun) {
                    // find first unused ip
                    getIpAddressConfiguration(candidate.address).fold({
                        dryRunIps = dryRunIps ++ Map(candidate.address -> candidate)
                        true
                    }){ _ => false }
                } else {
                    // reserve first unused ip
                    val resp = call(Http(s"$etcdAddr/ips/${candidate.address}?prevExist=false")
                        .params(Seq("value" -> Json.prettyPrint(candidate.toJson)))
                        .put(Array.empty[Byte]))
                    if (resp.code == 201) {
                        true
                    } else if (resp.code == 412) {
                        false
                    } else {
                        throw new EtcdException(s"unexpected response code (${resp.code}): ${resp.body}")
                    }
                }
            }).map(found => IpAddressConfiguration.fromOffsets(found._1, found._2, serviceName, nodeId).address)
        }

        allocateWithin(getServiceIds(serviceName)).getOrElse({
            var allocated: Option[String] = None
            while (allocated.isEmpty) {
                val nextServiceId = allocateServiceId(serviceName, isDryRun)
                allocated = allocateWithin(Seq(nextServiceId))
            }
            allocated.get
        })
    }

    def getServiceSeeds(serviceName: String, nodeId: String, count: Int): Seq[String] = {
        // if no head it is an internal error:
        // CONTAINER_IP should be allocated first in unfold chain
        val serviceId = getServiceIds(serviceName).head
        subnetIdRange.take(count)
            .map(j => IpAddressConfiguration.fromOffsets(serviceId, j, serviceName, nodeId).address)
    }

    private def getServiceIds(serviceName: String): Seq[Int] = {
        val resp = call(Http(s"$etcdAddr/services/?recursive=true"))
        if (resp.code == 200) {
            val responseParsed = Try((Json.parse(resp.body) \ "node").as[JsObject]).fold(
                ex => throw new InternalErrorException(resp.body, ex),
                r => r)
            val fetched = (responseParsed \ "nodes").asOpt[Seq[JsObject]].getOrElse(Seq.empty)
                .map(s => unpackNode(s))
                .filter(s => s._2 == serviceName)
                .map(s => s._1.substring("/services/".length).toInt)
                .sortBy(i => i)
            fetched ++ dryRunServices.filter(i => i._2 == serviceName).keys
        } else {
            throw new EtcdException(s"failure to get services (${resp.code}): ${resp.body}")
        }
    }

    private def allocateServiceId(serviceName: String, isDryRun: Boolean): Int = {
        val result = serviceIdRange
            .find(i => if (isDryRun) {
                // find first unused service id
                val resp = call(Http(s"$etcdAddr/services/$i"))
                if (resp.code == 200) {
                    false
                } else if (resp.code == 404) {
                    dryRunServices.get(i).fold({
                        dryRunServices = dryRunServices ++ Map(i -> serviceName)
                        true
                    }){_ => false}
                } else {
                    throw new EtcdException(s"unexpected response code (${resp.code}): ${resp.body}")
                }
            } else {
                // reserve first unused service id
                val resp = call(Http(s"$etcdAddr/services/$i?prevExist=false")
                    .params(Seq("value" -> serviceName))
                    .put(Array.empty[Byte]))
                if (resp.code == 201) {
                    true
                } else if (resp.code == 412) {
                    false
                } else {
                    throw new EtcdException(s"unexpected response code (${resp.code}): ${resp.body}")
                }
            })
        result.getOrElse(throw new PrerequisitesException("failure to locate available service identifier"))
    }

    private def boostrap() = {
        if (call(Http(s"$etcdAddr/nodes/")).code != 200) {
            // create directory with node ids, ignore the result
            // it is ok that it ignores dry-run, it happens only once anyway
            def createDir(dir: String) = {
                val response = call(Http(s"$etcdAddr/$dir")
                    .params(Seq("dir" -> "true"))
                    .put(Array.empty[Byte]))
                if (response.code != 201 && response.code != 403) {
                    throw new EtcdException(s"failure to create etcd /$dir directory (${response.code}): ${response.body}")
                }
            }
            createDir("nodes")
            createDir("services")
            createDir("ips")
        }
    }

    private def call(req: => HttpRequest): HttpResponse[String] = {
        Try(req.asString).fold(
            ex => throw new EtcdException(s"failure to request etcd cluster (unreachable): ${ex.getMessage}"),
            resp => resp
        )
    }

    private def unpack(body: String): JsValue = {
        val value = Try((Json.parse(body) \ "node" \ "value").as[String]).fold(
            ex => throw new InternalErrorException(body, ex),
            r => r
        )
        Json.parse(value)
    }

    private def unpackNode(s: JsValue): (String, String) = {
        Try((s \ "key").as[String])
            .fold(ex => throw new InternalErrorException(Json.prettyPrint(s), ex), r => r) ->
            Try((s \ "value").as[String])
                .fold(ex => throw new InternalErrorException(Json.prettyPrint(s), ex), r => r)
    }

    // from 10.32.1.0 to 10.47.255.254
    // 10.32.0.0/12 is hardcoded assigned range
    // last byte is reserved for increments within a service id:
    // 10.[32.0 + serviceId].[1-254]
    // so serviceId range [1, 4096)
    val serviceIdRange = Range(1, 1 << 12)
    // last byte of the ip address range [1-255)
    // the “.0” and “.-1” addresses in a subnet are not used, as required by RFC 1122
    val subnetIdRange = Range(1, (1 << 8) - 1)

    private val etcdAddr: String = "http://clusterlite-etcd:2379/v2/keys"
}