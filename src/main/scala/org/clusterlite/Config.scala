//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import play.api.libs.json._

import scala.util.Try

case class Service(image: String, options: Option[String], command: Option[String],
    environment: Option[Map[String, String]], dependencies: Option[Seq[String]],
    volumes: Option[Map[String, String]], stateless: Option[Boolean]) {
    def toJson: JsValue = ApplyConfiguration.toJson(this)
}
case class ServicePlacement(seeds: Option[Int], memory: Option[String], cpus: Option[Double]) {
    def toJson: JsValue = ApplyConfiguration.toJson(this)
}
case class Placement(services: Map[String, ServicePlacement], inherits: Option[String]) {
    def toJson: JsValue = ApplyConfiguration.toJson(this)
}
case class ApplyConfiguration(
    placements: Map[String, Placement], services: Map[String, Service], yaml: Option[String]) {
    def toJson: JsValue = ApplyConfiguration.toJson(this)
}

object ApplyConfiguration {
    implicit val serviceReader: OFormat[Service] = Json.format[Service]
    implicit val servicePlacementReader: OFormat[ServicePlacement] = Json.format[ServicePlacement]
    implicit val placementReader: OFormat[Placement] = Json.format[Placement]
    implicit val configurationReader: OFormat[ApplyConfiguration] = Json.format[ApplyConfiguration]

    def toJson(service: Service): JsValue = Json.toJson(service)
    def toJson(servicePlacement: ServicePlacement): JsValue = Json.toJson(servicePlacement)
    def toJson(placement: Placement): JsValue = Json.toJson(placement)
    def toJson(configuration: ApplyConfiguration): JsValue = Json.toJson(configuration)

    def fromJson(config: JsValue): ApplyConfiguration = {
        val mergedConf = Json.obj("placements" -> Json.obj(), "services" -> Json.obj()) ++ config.as[JsObject]
        Try(mergedConf.as[ApplyConfiguration]).fold(
            ex => throw new InternalErrorException(Json.prettyPrint(mergedConf), ex),
            r => r
        )
    }

    def fromJson(config: JsValue, yaml: String): ApplyConfiguration = {
        fromJson(config).copy(yaml = Some(yaml))
    }
}

case class LocalNodeConfiguration(
    token: String,
    seeds: Seq[String],
    volume: String,
    seedId: Option[Int],
    nodeUuid: String
) {
    def toJson: JsValue = LocalNodeConfiguration.toJson(this)
}

object LocalNodeConfiguration {
    implicit val format: OFormat[LocalNodeConfiguration] = Json.format[LocalNodeConfiguration]

    def toJson(config: LocalNodeConfiguration): JsValue = Json.toJson(config)

    def fromJson(config: JsObject): Option[LocalNodeConfiguration] = {
        if (config.fields.isEmpty) {
            None
        } else {
            Some(Try(config.as[LocalNodeConfiguration]).fold(
                ex => throw new InternalErrorException(Json.prettyPrint(config), ex),
                r => r
            ))
        }
    }
}

case class NodeConfiguration(
    nodeUuid: String,
    token: String,
    volume: String,
    placement: String,
    publicIp: String,
    weaveName: String,
    weaveNickName: String
) {
    def toJson: JsValue = NodeConfiguration.toJson(this)
}

object NodeConfiguration {
    implicit val format: OFormat[NodeConfiguration] = Json.format[NodeConfiguration]

    def toJson(config: NodeConfiguration): JsValue = Json.toJson(config)

    def fromJson(config: JsValue): NodeConfiguration = {
        Try(config.as[NodeConfiguration]).fold(
            ex => throw new InternalErrorException(Json.prettyPrint(config), ex),
            r => r
        )
    }
}

case class IpAddressConfiguration(
    address: String,
    nodeUuid: String,
    serviceName: String,
    serviceId: Int
) {
    def toJson: JsValue = IpAddressConfiguration.toJson(this)
}

object IpAddressConfiguration {
    implicit val format: OFormat[IpAddressConfiguration] = Json.format[IpAddressConfiguration]

    def toJson(config: IpAddressConfiguration): JsValue = Json.toJson(config)

    def fromJson(config: JsValue): IpAddressConfiguration = {
        Try(config.as[IpAddressConfiguration]).fold(
            ex => throw new InternalErrorException(Json.prettyPrint(config), ex),
            r => r
        )
    }

    def fromOffsets(i: Int, j: Int, serviceName: String, nodeId: String): IpAddressConfiguration = {
        IpAddressConfiguration(
            s"10.${i/0xFF + 32}.${i%0xFF}.$j",
            nodeId,
            serviceName,
            i)
    }
}

case class WeaveDns(Domain: String, Address: String)
case class WeaveRouter(Name: String, NickName: String)
case class WeaveState(Router: WeaveRouter, DNS: Option[WeaveDns])

object WeaveState {
    implicit val weaveDnsReads: Reads[WeaveDns] = Json.reads[WeaveDns]
    implicit val weaveRouterReads: Reads[WeaveRouter] = Json.reads[WeaveRouter]
    implicit val reads: Reads[WeaveState] = Json.reads[WeaveState]

    def fromJson(config: JsObject): Option[WeaveState] = {
        if (config.fields.isEmpty) {
            None
        } else {
            Some(Try(config.as[WeaveState]).fold(
                ex => throw new InternalErrorException(Json.prettyPrint(config), ex),
                r => r
            ))
        }
    }
}