//
// License: https://github.com/cadeworks/cade/blob/master/LICENSE
//

package works.cade

case class ImageReference(
    registry: String,
    vendor: Option[String],
    name: String
) {
    val reference: String = if (vendor.isDefined) {
        s"${vendor.get}/$name"
    } else {
        s"$name"
    }
}

object ImageReference {
    def apply(str: String): ImageReference = {
        val parts = str.split('/')
        parts.length match {
            case 1 => ImageReference("registry.hub.docker.com", None, parts(0))
            case 2 => ImageReference("registry.hub.docker.com", Some(parts(0)), parts(1))
            case _ => ImageReference(parts(0), Some(parts(1)), parts(2))
        }
    }
}
