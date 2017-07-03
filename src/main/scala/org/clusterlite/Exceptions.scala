//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import play.api.libs.json.{JsArray, Json}

abstract class TryErrorMessageBase {
    def toMessage: String
}
case class NoTryErrorMessage() extends TryErrorMessageBase {
    override def toMessage: String = ""
}
case class TryErrorMessage(msg: String, clarification: String) extends TryErrorMessageBase {
    override def toMessage = s"[clusterlite] Try '$msg' $clarification.\n"
}
case class HelpTryErrorMessage() extends TryErrorMessageBase {
    override def toMessage: String = "[clusterlite] Try 'clusterlite help' for more information\n"
}
case class MultiTryErrorMessage(msgs: Seq[TryErrorMessageBase]) extends TryErrorMessageBase {
    override def toMessage: String = msgs.map(i => i.toMessage).mkString("")
}

class BaseException(val msg: String, val category: String,
    val tryMsg: TryErrorMessageBase, val origin: Throwable) extends Exception(msg, origin) {
    def toMessage: String = {
           s"[clusterlite] Error: $getMessage\n${tryMsg.toMessage}[clusterlite] failure: $category"
    }
}

// unhandled internal error
class InternalErrorException(msg: String, origin: Throwable = null) extends BaseException(
    msg,
    "internal error, please report to https://github.com/webintrinsics/clusterlite",
    NoTryErrorMessage(),
    origin)

// handled client errors
class ParseException(msg: String, tryMsg: TryErrorMessageBase,
    origin: Throwable = null) extends BaseException(
    msg,
    "invalid argument(s)",
    tryMsg,
    origin)
class ConfigException(errors: JsArray) extends BaseException(
    Json.prettyPrint(errors),
    "invalid configuration file",
    HelpTryErrorMessage(),
    null)
class PrerequisitesException(msg: String, tryMsg: TryErrorMessageBase, origin: Throwable = null) extends BaseException(
    msg,
    "prerequisites not satisfied",
    tryMsg,
    origin)

// handled server errors
class EtcdException(msg: String, origin: Throwable = null) extends BaseException(
    msg,
    "clusterlite-etcd error",
    MultiTryErrorMessage(Seq(
        TryErrorMessage("clusterlite nodes", "to check if seed node(s) is(are) reachable"),
        TryErrorMessage("docker start clusterlite-etcd", "on seed node(s) to launch etcd server(s)"),
        TryErrorMessage("docker logs clusterlite-etcd", "on seed node(s) for logs from etcd server(s)"),
        TryErrorMessage("docker inspect clusterlite-etcd", "on seed node(s) for more information")
    )),
    origin)
class ProxyException(nodeId: Int, nodeName: String, origin: Throwable = null) extends BaseException(
    s"docker proxy for node $nodeId is not reachable",
    "clusterlite-proxy error",
    MultiTryErrorMessage(Seq(
        TryErrorMessage(s"ping $nodeName", "to check if the node is reachable"),
        TryErrorMessage(s"clusterlite nodes | grep $nodeName", "to check if the node is listed and reachable"),
        TryErrorMessage("docker start clusterlite-proxy", "on the target node to launch the proxy server"),
        TryErrorMessage("docker logs clusterlite-proxy", "on the target node for logs from proxy server"),
        TryErrorMessage("docker inspect clusterlite-proxy", "on the target node for more information")
    )),
    origin)

// handled external errors
class AnyDockerException(msg: String, origin: Throwable) extends BaseException(
    msg,
    "docker error",
    NoTryErrorMessage(),
    origin)
class RegistryException(target: String, msg: String, origin: Throwable) extends BaseException(
    s"connection to $target is not available: $msg",
    "connection error",
    TryErrorMessage(s"ping $target", "to check connectivity"),
    origin)
class AuthenticationException(registry: String, username: String, password: String, origin: Throwable) extends BaseException(
    s"authentication failed by $registry for $username with ${password.length} characters password",
    "prerequisites not satisfied",
    TryErrorMessage(s"clusterlite login --registry $registry --username $username --password <password>",
        "to set the valid password"),
    origin)
class AggregatedException(origins: Seq[BaseException]) extends BaseException(
    "",
    "multiple error(s)",
    MultiTryErrorMessage(origins.map(o => o.tryMsg).distinct),
    null) {
    override def toMessage: String = {
        val errors = origins.map(o => s"[clusterlite] Error: ${o.getMessage}\n").distinct.mkString("")
        s"$errors${tryMsg.toMessage}[clusterlite] failure: $category"
    }
}
