//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

trait Env {
    def get(name: String): String = {
        getOrElse(name, throw new EnvironmentException(s"$name environment variable is not defined, " +
            "invocation from the back door or internal error? Use clusterlite start script"))
    }
    def getOrElse(name: String, default: => String): String

    override def toString: String = {
        val addressesV4 = getOrElse(Env.Ipv4Addresses, "").split(",").zipWithIndex
            .map(a => s"${Env.Ipv4Addresses}[${a._2}]=${a._1}")
            .mkString("\n#    ")
        val addressesV6 = getOrElse(Env.Ipv6Addresses, "").split(",").zipWithIndex
            .map(a => s"${Env.Ipv6Addresses}[${a._2}]=${a._1}")
            .mkString("\n#    ")
        s"""
            |#    ${Env.ClusterliteId}=${getOrElse(Env.ClusterliteId, "null")}
            |#    ${Env.ClusterliteData}=${getOrElse(Env.ClusterliteData, "null")}
            |#    ${Env.Hostname}=${getOrElse(Env.Hostname, "null")}
            |#    ${Env.HostnameI}=${getOrElse(Env.HostnameI, "null")}
            |#    $addressesV4
            |#    $addressesV6
            |#""".stripMargin
    }
}

object Env {
    val ClusterliteId = "CLUSTERLITE_ID"
    val ClusterliteData = "CLUSTERLITE_DATA"
    val Hostname = "HOSTNAME"
    val HostnameI = "HOSTNAME_I"
    val Ipv4Addresses = "IPV4_ADDRESSES"
    val Ipv6Addresses = "IPV6_ADDRESSES"

    def apply(source: Map[String, String]): Env = {
        class EnvMap(source: Map[String, String]) extends Env {
            override def getOrElse(name: String,
                default: => String): String = source.getOrElse(name, default)
        }
        new EnvMap(source)
    }

    def apply(): Env = {
        class EnvSystem extends Env {
            override def getOrElse(name: String,
                default: => String): String = Option(System.getenv(name)).getOrElse(default)
        }
        new EnvSystem
    }
}
