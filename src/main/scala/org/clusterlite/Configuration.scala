//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import play.api.libs.json._

case class Service(image: String, options: Option[String], command: Option[String],
    environment: Option[Map[String, String]], dependencies: Option[Seq[String]],
    volumes: Option[Map[String, String]], stateless: Option[Boolean]) {
    def toJson: JsValue = ConfigurationSerializer.toJson(this)
}
case class ServicePlacement(memory: Option[String], cpus: Option[Double]) {
    def toJson: JsValue = ConfigurationSerializer.toJson(this)
}
case class Placement(services: Map[String, ServicePlacement], inherits: Option[String]) {
    def toJson: JsValue = ConfigurationSerializer.toJson(this)
}
case class Configuration(placements: Map[String, Placement], services: Map[String, Service]) {
    def toJson: JsValue = ConfigurationSerializer.toJson(this)
}

object ConfigurationSerializer {
    implicit val serviceReader: OFormat[Service] = Json.format[Service]
    implicit val servicePlacementReader: OFormat[ServicePlacement] = Json.format[ServicePlacement]
    implicit val placementReader: OFormat[Placement] = Json.format[Placement]
    implicit val configurationReader: OFormat[Configuration] = Json.format[Configuration]

    def toJson(service: Service): JsValue = Json.toJson(service)
    def toJson(servicePlacement: ServicePlacement): JsValue = Json.toJson(servicePlacement)
    def toJson(placement: Placement): JsValue = Json.toJson(placement)
    def toJson(configuration: Configuration): JsValue = Json.toJson(configuration)

    def fromJson(config: JsObject): Configuration = {
        (Json.obj("placements" -> Json.obj(), "services" -> Json.obj()) ++ config).as[Configuration]
    }
}

case class SystemConfiguration(
    token: String, // immutable, remove
    seeds: Seq[String], // immutable, remove
    volume: String, // immutable, save to local disk and to etcd
    placement: String, // mutable, move to assign command, save to etcd
    publicIp: String, // mutable, move to assign command, save to etcd
    seedId: Option[Int], // immutable, remove or save to local disk
    nodeId: Option[Int] // immutable, obtain during assign command, save to etcd as well as guid, weave name and nickname
) {
    def toJson: JsValue = SystemConfigurationSerializer.toJson(this)
}

object SystemConfigurationSerializer {
    implicit val systemConfigurationFormat: OFormat[SystemConfiguration] = Json.format[SystemConfiguration]

    def toJson(systemConfiguration: SystemConfiguration): JsValue = Json.toJson(systemConfiguration)

    def fromJson(config: JsObject): Option[SystemConfiguration] = {
        if (config.fields.isEmpty) {
            None
        } else {
            Some(config.as[SystemConfiguration])
        }
    }
}

case class WeaveDns(Domain: String, Address: String)
case class WeaveRouter(Name: String, NickName: String)
case class WeaveState(Router: WeaveRouter, DNS: Option[WeaveDns])

object WeaveStateSerializer {
    implicit val weaveDnsReads: Reads[WeaveDns] = Json.reads[WeaveDns]
    implicit val weaveRouterReads: Reads[WeaveRouter] = Json.reads[WeaveRouter]
    implicit val reads: Reads[WeaveState] = Json.reads[WeaveState]

    def fromJson(config: JsObject): Option[WeaveState] = {
        if (config.fields.isEmpty) {
            None
        } else {
            Some(config.as[WeaveState])
        }
    }
}