package demo

import language.experimental.macros
import scala.reflect.macros.blackbox.Context

class a {
  def x(c: Context) = {
    import c.universe._
    reify { type T = Option[_]; () }.tree
  }
  def y(c: Context) = {
    import c.universe._
    reify { type T = Option[_]; () }.tree
  }
}
