//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import play.api.libs.json._

import scala.util.Try

case class ServiceDependency(env: String) {
    def toJson: JsValue = ApplyConfiguration.toJson(this)
}
case class Service(image: String, options: Option[String], command: Option[Vector[JsValue]],
    environment: Option[Map[String, String]], dependencies: Option[Map[String, ServiceDependency]],
    files: Option[Map[String, String]],
    volumes: Option[Map[String, String]], stateless: Option[Boolean]) {
    def toJson: JsValue = ApplyConfiguration.toJson(this)
}
case class ServicePlacement(seeds: Option[Int], ports: Option[Map[String, Int]],
    memory: Option[String], cpus: Option[Double]) {
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
    implicit val serviceDependencyReader: OFormat[ServiceDependency] = Json.format[ServiceDependency]
    implicit val serviceReader: OFormat[Service] = Json.format[Service]
    implicit val servicePlacementReader: OFormat[ServicePlacement] = Json.format[ServicePlacement]
    implicit val placementReader: OFormat[Placement] = Json.format[Placement]
    implicit val configurationReader: OFormat[ApplyConfiguration] = Json.format[ApplyConfiguration]

    def toJson(service: Service): JsValue = Json.toJson(service)
    def toJson(servicePlacement: ServicePlacement): JsValue = Json.toJson(servicePlacement)
    def toJson(serviceDependency: ServiceDependency): JsValue = Json.toJson(serviceDependency)
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


case class CredentialsConfiguration(
    registry: String = "registry.hub.docker.com",
    username: Option[String] = None,
    password: Option[String] = None// TODO encrypt password
) {
    def toJson: JsValue = CredentialsConfiguration.toJson(this)
}

object CredentialsConfiguration {
    implicit val format: OFormat[CredentialsConfiguration] = Json.format[CredentialsConfiguration]

    def toJson(config: CredentialsConfiguration): JsValue = Json.toJson(config)

    def fromJson(config: JsValue): CredentialsConfiguration = {
        Try(config.as[CredentialsConfiguration]).fold(
            ex => throw new InternalErrorException(Json.prettyPrint(config), ex),
            r => r
        )
    }
}

case class NodeConfiguration(
    nodeId: Int,
    token: String,
    volume: String,
    placement: String,
    publicIp: String,
    weaveName: String,
    weaveNickName: String,
    seeds: Vector[String],
    seedId: Option[Int]
) {
    def toJson: JsValue = NodeConfiguration.toJson(this)

    def proxyAddress: String = {
        s"10.47.${240 + nodeId / 0xFF}.${nodeId % 0xFF}"
    }
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

    def fromString(nodeId: Int, str: String): NodeConfiguration = {
        val parts = str.split(',')
        val weaveName = parts(0).split('(')(0)
        val weaveNickName = parts(0).split('(')(1).dropRight(1)
        val token = parts(1)
        val volume = parts(2)
        val placement = parts(3)
        val publicIp = parts(4)
        val seeds = parts(5).split(':')
        val seedId = if (parts.length < 7) None else Some(parts(6).toInt)
        NodeConfiguration(nodeId, token, volume, placement, publicIp, weaveName, weaveNickName, seeds, seedId)
    }
}

case class IpAddressConfiguration(
    address: String,
    nodeId: Int,
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

    def fromOffsets(i: Int, j: Int, serviceName: String, nodeId: Int): IpAddressConfiguration = {
        IpAddressConfiguration(
            s"10.${i/0xFF + 32}.${i%0xFF}.$j",
            nodeId,
            serviceName,
            i)
    }
}
