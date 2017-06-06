//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import scala.util.Try
import scalaj.http.{Http, HttpRequest, HttpResponse}

object EtcdClient {
    def call(req: => HttpRequest): HttpResponse[String] = {
        Try(req.asString).fold(
            ex => throw new ErrorException(s"failure to request etcd cluster (unreachable): ${ex.getMessage}"),
            resp => resp
        )
    }

    def reserveNodeId(nodeName: String, isDryRun: Boolean): Int = {
        // create directory with node ids, ignore the result (should happen once)
        val response = call(Http("http://clusterlite-etcd:2379/v2/keys/nodes")
            .params(Seq("dir" -> "true"))
            .put(Array.empty[Byte]))
        if (response.code != 201 && response.code != 403) {
            throw new ErrorException(s"failure to create etcd /nodes directory (${response.code}): ${response.body}")
        }

        val result = Range(1, 2001)
            .find(i => if (isDryRun) {
                // find first unused node id
                call(Http(s"http://clusterlite-etcd:2379/v2/keys/nodes/$i")).code == 404
            } else {
                // reserve first unused node id
                call(Http(s"http://clusterlite-etcd:2379/v2/keys/nodes/$i?prevExist=false")
                    .params(Seq("value" -> nodeName))
                    .put(Array.empty[Byte])).code == 201
            })
        result.getOrElse(throw new ErrorException("failure to locate available node identifier"))
    }
}