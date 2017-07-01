//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import play.api.libs.json.{JsObject, JsValue, Json}

import scala.util.Try
import scalaj.http.{Http, HttpRequest, HttpResponse}

object EtcdStore {
    def getNodes: Map[Int, NodeConfiguration] = {
        val resp = call(Http(s"$etcdAddr/nodes/?recursive=true"))
        if (resp.code == 200) {
            val responseParsed = Try((Json.parse(resp.body) \ "node").as[JsObject]).fold(
                ex => throw new InternalErrorException(resp.body, ex),
                r => r)
            val rows = (responseParsed \ "nodes").asOpt[Seq[JsObject]].getOrElse(Seq.empty)
                .map(s => {
                    val n = unpackNode(s)
                    n._1.substring("/nodes/".length) -> n._2
                })
            val rawRows = rows
                .filter(s => !s._1.endsWith(".json"))
                .map(i => i._1.toInt -> NodeConfiguration.fromString(i._1.toInt, i._2))
                .toMap
            val jsonRows = rows
                .filter(s => s._1.endsWith(".json"))
                .map(i => i._1.split('.')(0).toInt -> NodeConfiguration.fromJson(Json.parse(i._2)))
                .toMap
            rawRows.foreach(i => {
                // clone if it was not done before (for new recent nodes)
                if (!jsonRows.contains(i._1)) {
                    setNodeConfig(i._2)
                }
            })
            rawRows ++ jsonRows
        } else {
            throw new EtcdException(s"failure to fetch configuration (${resp.code}): ${resp.body}")
        }
    }

    def getNodeConfig(nodeId: Int): Option[NodeConfiguration] = {
        getNodes.get(nodeId)
    }

    private def setNodeConfig(config: NodeConfiguration): NodeConfiguration = {
        val response = call(Http(s"$etcdAddr/nodes/${config.nodeId}.json")
            .params(Seq("value" -> Json.prettyPrint(config.toJson)))
            .put(Array.empty[Byte]))
        if (response.code < 200 || response.code > 299) {
            throw new EtcdException(s"failure to save node configuration (${response.code}): ${response.body}")
        }
        config
    }

    def getCredentials: Vector[CredentialsConfiguration] = {
        val resp = call(Http(s"$etcdAddr/credentials"))
        if (resp.code == 200) {
            val responseParsed = Try((Json.parse(resp.body) \ "node").as[JsObject]).fold(
                ex => throw new InternalErrorException(resp.body, ex),
                r => r)
            val rows = (responseParsed \ "nodes").asOpt[Seq[JsObject]].getOrElse(Seq.empty)
                .map(s => {
                    val n = unpackNode(s)
                    CredentialsConfiguration.fromJson(Json.parse(n._2))
                })
            rows.filter(i => i.username.isDefined).toVector
        } else if (resp.code == 404) {
            Vector()
        } else {
            throw new EtcdException(s"failure to fetch credentials configurations (${resp.code}): ${resp.body}")
        }
    }

    def getCredentials(registry: String): CredentialsConfiguration = {
        val resp = call(Http(s"$etcdAddr/credentials/$registry"))
        if (resp.code == 200) {
            CredentialsConfiguration.fromJson(unpack(resp.body))
        } else if (resp.code == 404) {
            CredentialsConfiguration(registry, None, None)
        } else {
            throw new EtcdException(s"failure to fetch credentials configuration (${resp.code}): ${resp.body}")
        }
    }

    def setCredentials(credentials: CredentialsConfiguration): CredentialsConfiguration = {
        val response = call(Http(s"$etcdAddr/credentials/${credentials.registry}")
            .params(Seq("value" -> Json.prettyPrint(credentials.toJson)))
            .put(Array.empty[Byte]))
        if (response.code < 200 || response.code > 299) {
            throw new EtcdException(s"failure to save credentials configuration (${response.code}): ${response.body}")
        }
        credentials
    }

    def deleteCredentials(registry: String): Boolean = {
        val resp = call(Http(s"$etcdAddr/credentials/$registry").method("DELETE"))
        if (resp.code == 404) {
            false
        } else if (resp.code < 200 || resp.code > 299) {
            throw new EtcdException(s"failure to delete file (${resp.code}): ${resp.body}")
        } else {
            true
        }
    }

    def getFiles: Vector[String] = {
        val resp = call(Http(s"$etcdAddr/files"))
        if (resp.code == 200) {
            val responseParsed = Try((Json.parse(resp.body) \ "node").as[JsObject]).fold(
                ex => throw new InternalErrorException(resp.body, ex),
                r => r)
            val rows = (responseParsed \ "nodes").asOpt[Seq[JsObject]].getOrElse(Seq.empty)
                .map(s => {
                    val n = unpackNode(s)
                    n._1.substring("/files/".length)
                })
            rows.toVector
        } else if (resp.code == 404) {
            Vector()
        } else {
            throw new EtcdException(s"failure to fetch configuration (${resp.code}): ${resp.body}")
        }
    }

    def getFile(target: String): Option[String] = {
        val resp = call(Http(s"$etcdAddr/files/$target"))
        if (resp.code == 200) {
            Some(unpackString(resp.body))
        } else if (resp.code == 404) {
            None
        } else {
            throw new EtcdException(s"failure to fetch file content (${resp.code}): ${resp.body}")
        }
    }

    def setFile(target: String, content: String): Unit = {
        // This is a workaround for etcd bug.
        // If this line is removed, etcd fails to accept large file
        // the error thrown is the following:
        // "failure to request etcd cluster (unreachable): Error writing to server"
        call(Http(s"$etcdAddr/files"))

        val response = call(Http(s"$etcdAddr/files/$target")
            .params(Seq("value" -> content))
            .put(Array.empty[Byte]))
        if (response.code < 200 || response.code > 299) {
            throw new EtcdException(s"failure to save file content (${response.code}): ${response.body}")
        }
    }

    def deleteFile(target: String): Boolean = {
        val resp = call(Http(s"$etcdAddr/files/$target").method("DELETE"))
        if (resp.code == 404) {
            false
        } else if (resp.code < 200 || resp.code > 299) {
            throw new EtcdException(s"failure to delete file (${resp.code}): ${resp.body}")
        } else {
            true
        }
    }

    def getApplyConfig: ApplyConfiguration = {
        val resp = call(Http(s"$etcdAddr/apply.json"))
        if (resp.code == 200) {
            ApplyConfiguration.fromJson(unpack(resp.body))
        } else if (resp.code == 404) {
            ApplyConfiguration.fromJson(Json.obj())
        } else {
            throw new EtcdException(s"failure to fetch configuration (${resp.code}): ${resp.body}")
        }
    }

    def setApplyConfig(config: ApplyConfiguration): ApplyConfiguration = {
        val response = call(Http(s"$etcdAddr/apply.json")
            .params(Seq("value" -> Json.prettyPrint(config.toJson)))
            .put(Array.empty[Byte]))
        if (response.code < 200 || response.code > 299) {
            throw new EtcdException(s"failure to save apply configuration (${response.code}): ${response.body}")
        }
        config
    }

    def getIpAddressConfiguration(address: String): Option[IpAddressConfiguration] = {
        val resp = call(Http(s"$etcdAddr/ips/$address"))
        if (resp.code == 200) {
            Some(IpAddressConfiguration.fromJson(unpack(resp.body)))
        } else if (resp.code == 404) {
            None
        } else {
            throw new EtcdException(s"unexpected response code (${resp.code}): ${resp.body}")
        }
    }

    def getOrAllocateIpAddressConfiguration(serviceName: String, nodeId: Int): String = {
        val candidates = getServiceIds(serviceName).flatMap(i => subnetIdRange.map(j => i -> j))
        val maybeFound = candidates.find(c => {
            val candidate = IpAddressConfiguration.fromOffsets(c._1, c._2, serviceName, nodeId)
            getIpAddressConfiguration(candidate.address).fold(false){
                f => f.nodeId == nodeId && f.serviceName == serviceName
            }
        }).map(f => IpAddressConfiguration.fromOffsets(f._1, f._2, serviceName, nodeId).address)
        maybeFound.getOrElse(allocateIpAddressConfiguration(serviceName, nodeId))
    }

    private def allocateIpAddressConfiguration(serviceName: String, nodeId: Int): String = {
        def allocateWithin(serviceIds: Seq[Int]) = {
            val candidates = serviceIds.flatMap(i => subnetIdRange.map(j => i -> j))
            candidates.find(c => {
                val candidate = IpAddressConfiguration.fromOffsets(c._1, c._2, serviceName, nodeId)
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
            }).map(found => IpAddressConfiguration.fromOffsets(found._1, found._2, serviceName, nodeId).address)
        }

        allocateWithin(getServiceIds(serviceName)).getOrElse({
            var allocated: Option[String] = None
            while (allocated.isEmpty) {
                val nextServiceId = allocateServiceId(serviceName)
                allocated = allocateWithin(Seq(nextServiceId))
            }
            allocated.get
        })
    }

    def getServiceSeeds(serviceName: String, nodeId: Int, count: Int): Seq[String] = {
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
            (responseParsed \ "nodes").asOpt[Seq[JsObject]].getOrElse(Seq.empty)
                .map(s => unpackNode(s))
                .filter(s => s._2 == serviceName)
                .map(s => s._1.substring("/services/".length).toInt)
                .sortBy(i => i)
        } else {
            throw new EtcdException(s"failure to get services (${resp.code}): ${resp.body}")
        }
    }

    private def allocateServiceId(serviceName: String): Int = {
        val result = serviceIdRange
            .find(i => {
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
        result.getOrElse(throw new PrerequisitesException(
            "[clusterlite] Error: problem to allocate service identifier\n" +
                "[clusterlite] Have you configured more services * containers then IP address range allows?"))
    }

//    private def bootstrap() = {
//        if (call(Http(s"$etcdAddr/nodes/")).code != 200) {
//            System.err.println("Booting etcd storage...")
//            // create directory with node ids, ignore the result
//            def createDir(dir: String) = {
//                val response = call(Http(s"$etcdAddr/$dir")
//                    .params(Seq("dir" -> "true"))
//                    .put(Array.empty[Byte]))
//                if (response.code != 201 && response.code != 403) {
//                    throw new EtcdException(s"failure to create etcd /$dir directory (${response.code}): ${response.body}")
//                }
//            }
//            createDir("nodes")
//            createDir("services")
//            createDir("ips")
//            createDir("credentials")
//            createDir("files")
//        }
//    }

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

    private def unpackString(body: String): String = {
        val value = Try((Json.parse(body) \ "node" \ "value").as[String]).fold(
            ex => throw new InternalErrorException(body, ex),
            r => r
        )
        value
    }

    private def unpackNode(s: JsValue): (String, String) = {
        Try((s \ "key").as[String])
            .fold(ex => throw new InternalErrorException(Json.prettyPrint(s), ex), r => r) ->
            Try((s \ "value").as[String])
                .fold(ex => throw new InternalErrorException(Json.prettyPrint(s), ex), r => r)
    }

    // from 10.32.1.0 to 10.47.239.254
    // 10.32.0.0/12 is hardcoded assigned range
    // 10.47.240.0/20 is reserved for node proxies and automated IP assignment
    // last byte is reserved for increments within a service id:
    // 10.[32.1 + serviceId].[1-254]
    // so serviceId range [1, 4080)
    val serviceIdRange = Range(1, 1 << 12 - 16)
    // last byte of the ip address range [1-255)
    // the “.0” and “.-1” addresses in a subnet are not used, as required by RFC 1122
    val subnetIdRange = Range(1, (1 << 8) - 1)

    private val etcdAddr: String = "http://clusterlite-etcd:2379/v2/keys"
}