logLevel := Level.Info

// one-jar assembly
addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "0.14.1")

// unversal zip packager
addSbtPlugin("com.typesafe.sbt" % "sbt-native-packager" % "1.1.6")

// static analysis
addSbtPlugin("org.scalastyle" %% "scalastyle-sbt-plugin" % "0.8.0")

// code coverage
addSbtPlugin("org.scoverage" % "sbt-scoverage" % "1.5.0")

