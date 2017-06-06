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
    token: String,
    seeds: Seq[String],
    volume: String,
    placement: String,
    publicIp: String,
    seedId: Option[Int],
    nodeId: Option[Int]
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
case class WeaveState(DNS: Option[WeaveDns])

object WeaveStateSerializer {
    implicit val weaveDnsReads: Reads[WeaveDns] = Json.reads[WeaveDns]
    implicit val reads: Reads[WeaveState] = Json.reads[WeaveState]

    def fromJson(config: JsObject): Option[WeaveState] = {
        if (config.fields.isEmpty) {
            None
        } else {
            Some(config.as[WeaveState])
        }
    }
}