//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import play.api.libs.json.{JsArray, Json}

class InternalErrorException(msg: String, origin: Throwable = null) extends Exception(msg, origin)
class EtcdException(msg: String) extends Exception(msg)
class ParseException(msg: String = "") extends Exception(msg)
class EnvironmentException(msg: String) extends Exception(msg)
class TimeoutException(msg: String) extends Exception(msg)
class PrerequisitesException(msg: String) extends Exception(msg)
class ConfigException(errors: JsArray)
    extends Exception(s"Errors:\n${Json.prettyPrint(errors)}\n" +
        "Try --help for more information.")
