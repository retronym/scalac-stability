package demo

import language.experimental.macros
import scala.reflect.macros.blackbox.Context

object Macro {
  def impl(c: Context): c.Tree = {
    import c.universe._
    val name = c.freshName("foo")
    Block(ValDef(NoMods, TermName(name), tq"_root_.scala.Int", Literal(Constant(0))) :: Nil, Ident(name))
  }
  def m: Unit = macro impl
}
