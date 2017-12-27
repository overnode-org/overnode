//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

trait Env {
    def get(name: String): String = {
        getOrElse(name, throw new InternalErrorException(
            s"$name environment variable is not defined, " +
            "invocation from the back door or an internal error?"))
    }
    def getOrElse(name: String, default: => String): String = {
        getOption(name).getOrElse(default)
    }
    protected def getOption(name: String): Option[String]

    def isDebug: Boolean = {
        get(Env.Debug) == "true"
    }

    def version: String = get(Env.Version)

    override def toString: String = {
        val addressesV4 = getOrElse(Env.Ipv4Addresses, "").split(",").zipWithIndex
            .map(a => s"${Env.Ipv4Addresses}[${a._2}]=${a._1}")
            .mkString("\n#    ")
        val addressesV6 = getOrElse(Env.Ipv6Addresses, "").split(",").zipWithIndex
            .map(a => s"${Env.Ipv6Addresses}[${a._2}]=${a._1}")
            .mkString("\n#    ")
        s"""Env[
            |    ${Env.OperationId}=${getOrElse(Env.OperationId, "null")}
            |    ${Env.NodeId}=${getOrElse(Env.NodeId, "null")}
            |    ${Env.Volume}=${getOrElse(Env.Volume, "null")}
            |    ${Env.SeedId}=${getOrElse(Env.SeedId, "null")}
            |    ${Env.Version}=${getOrElse(Env.Version, "null")}
            |    ${Env.Hostname}=${getOrElse(Env.Hostname, "null")}
            |    $addressesV4
            |    $addressesV6
            |]""".stripMargin
    }
}

object Env {
    val OperationId = "CLUSTERLITE_OPERATION_ID"
    val NodeId = "CLUSTERLITE_NODE_ID"
    val Volume = "CLUSTERLITE_VOLUME"
    val SeedId = "CLUSTERLITE_SEED_ID"
    val Debug = "CLUSTERLITE_DEBUG"
    val Version = "CLUSTERLITE_VERSION"
    // the following variables are available only for install command
    val Hostname = "CLUSTERLITE_HOSTNAME"
    val Ipv4Addresses = "CLUSTERLITE_IPV4_ADDRESSES"
    val Ipv6Addresses = "CLUSTERLITE_IPV6_ADDRESSES"

    def apply(source: Map[String, String]): Env = {
        class EnvMap(source: Map[String, String]) extends Env {
            override def getOption(name: String): Option[String] = source.get(name)
        }
        new EnvMap(source)
    }

    def apply(): Env = {
        class EnvSystem extends Env {
            override def getOption(name: String): Option[String] = Option(System.getenv(name))
        }
        new EnvSystem
    }
}
