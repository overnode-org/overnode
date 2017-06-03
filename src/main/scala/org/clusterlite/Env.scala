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
        s"""
            |#    CLUSTERLITE_ID=${getOrElse(Env.ClusterliteId, "null")}
            |#    CLUSTERLITE_DATA=${getOrElse(Env.ClusterliteData, "null")}
            |#    HOSTNAME=${getOrElse(Env.Hostname, "null")}
            |#    HOSTNAME_I=${getOrElse(Env.HostnameI, "null")}
            |#    WEAVE_VERSION=${getOrElse(Env.WeaveVersion, "null")}
            |#    IPV4_ADDRESSES=${getOrElse(Env.Ipv4Addresses, "null")}
            |#    IPV6_ADDRESSES=${getOrElse(Env.Ipv6Addresses, "null")}
            |#""".stripMargin
    }
}

object Env {
    val ClusterliteId = "CLUSTERLITE_ID"
    val ClusterliteData = "CLUSTERLITE_DATA"
    val Hostname = "HOSTNAME"
    val HostnameI = "HOSTNAME_I"
    val WeaveVersion = "WEAVE_VERSION"
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
