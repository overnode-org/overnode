//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.nio.file.{Files, Paths}
import java.security.MessageDigest

import scala.io.Source

object Utils {
    def quote(str: String): String = {
        "\"" + str + "\""
    }
    def quoteIfMultiWord(str: String): String = {
        val singeLine = str.replace("\r\n", " ").replace("\n", " ")
        if (singeLine.contains(" ")) {
            quote(singeLine)
        } else {
            singeLine
        }
    }

    def wrapEcho(str: String): String = {
        s"\n$str\n"
    }

    def md5(s: String) = MessageDigest.getInstance("MD5")
        .digest(s.getBytes).map("%02X".format(_)).mkString

    def loadFromResource(resource: String): String = {
        val source = Source.fromURL(getClass.getResource(s"/$resource"))
        source.getLines().mkString("\n").replaceAll("\r\n", "\n")
    }

    def loadFromFile(dir: String, resource: String): String = {
        new String(Files.readAllBytes(Paths.get(s"$dir/$resource")))
    }

    def loadFromFileIfExists(dir: String, resource: String): Option[String] = {
        val path = Paths.get(s"$dir/$resource")
        if (path.toFile.exists()) {
            Some(new String(Files.readAllBytes(path)))
        } else {
            None
        }
    }
}
