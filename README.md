# Unstable compiler output

Test cases to show ways that a given Scala source file can produce inconsistent classfile depending on the order of source files.

## Lambda lift

Type completion can change order of typechecking methods in a class, resulting in Symbol.ids. Lambda lift places symbols-to-be-renamed in a [tree set](https://github.com/scala/scala/blob/9acab45aeeadef2f63da69faf81465cc15599789/src/compiler/scala/tools/nsc/transform/LambdaLift.scala#L67-L74), ordered by `Symbol.isLess` (which for term symbols amounts to ordering by `Symbol.id`).

[Test Case](lambdalift)
```
+ mkdir -p target1 target2
+ scalac -d target1 -nowarn -Xprint:all a.scala b.scala
+ egrep -v '\.scala'
+ scalac -d target2 -nowarn -Xprint:all b.scala a.scala
+ egrep -v '\.scala'
+ diff -u /dev/fd/63 /dev/fd/62
++ show target1 demo.a
++ show target2 demo.a
++ javap -cp target1 -private -v demo.a
++ javap -cp target2 -private -v demo.a
++ egrep -v 'Classfile|checksum'
++ egrep -v 'Classfile|checksum'
--- /dev/fd/63  2018-01-10 13:20:15.000000000 +1000
+++ /dev/fd/62  2018-01-10 13:20:15.000000000 +1000
@@ -18,10 +18,10 @@
   #11 = Utf8               this
   #12 = Utf8               Ldemo/a;
   #13 = Utf8               y
-  #14 = Utf8               local$1
+  #14 = Utf8               local$2
   #15 = Utf8               ()Ljava/lang/String;
   #16 = String             #9             // x
-  #17 = Utf8               local$2
+  #17 = Utf8               local$1
   #18 = String             #13            // y
   #19 = Utf8               <init>
   #20 = NameAndType        #19:#10        // "<init>":()V
@@ -58,7 +58,7 @@
       LineNumberTable:
         line 9: 0

-  private static final java.lang.String local$1();
+  private static final java.lang.String local$2();
     descriptor: ()Ljava/lang/String;
     flags: ACC_PRIVATE, ACC_STATIC, ACC_FINAL
     Code:
@@ -68,7 +68,7 @@
       LineNumberTable:
         line 5: 0

-  private static final java.lang.String local$2();
+  private static final java.lang.String local$1();
     descriptor: ()Ljava/lang/String;
     flags: ACC_PRIVATE, ACC_STATIC, ACC_FINAL
     Code:
@@ -98,7 +98,7 @@
   0: #6(#7=s#8)
 Error: unknown attribute
   ScalaInlineInfo: length = 0x1D
-   01 00 00 05 00 13 00 0A 00 00 0E 00 0F 01 00 11
+   01 00 00 05 00 13 00 0A 00 00 11 00 0F 01 00 0E
    00 0F 01 00 09 00 0A 00 00 0D 00 0A 00
 Error: unknown attribute
   ScalaSig: length = 0x3

```

### Macro Fresh Names

Macro fresh names for a given prefix are [globally numbered](https://github.com/scala/scala/blob/9acab45aeeadef2f63da69faf81465cc15599789/src/reflect/scala/reflect/internal/FreshNames.scala#L13-L15), rather than using a per-compilation unit counter. This is a symptomatic fix for hygiene problems described in https://github.com/scala/bug/issues/6879.

[Test Case](macros)

```
+ mkdir -p target target1 target2
+ scalac -d target -nowarn macro.scala
+ scalac -cp target -d target1 -nowarn a.scala b.scala
+ scalac -cp target -d target2 -nowarn b.scala a.scala
+ diff -u /dev/fd/63 /dev/fd/62
++ show target1 demo.a
++ show target2 demo.a
++ javap -cp target1 -v demo.a
++ javap -cp target2 -v demo.a
++ egrep -v 'Classfile|checksum'
++ egrep -v 'Classfile|checksum'
--- /dev/fd/63  2018-01-10 13:24:37.000000000 +1000
+++ /dev/fd/62  2018-01-10 13:24:37.000000000 +1000
@@ -21,7 +21,7 @@
   #14 = Utf8               Lscala/runtime/BoxedUnit;
   #15 = NameAndType        #13:#14        // UNIT:Lscala/runtime/BoxedUnit;
   #16 = Fieldref           #12.#15        // scala/runtime/BoxedUnit.UNIT:Lscala/runtime/BoxedUnit;
-  #17 = Utf8               foo$macro$1
+  #17 = Utf8               foo$macro$2
   #18 = Utf8               I
   #19 = Utf8               this
   #20 = Utf8               Ldemo/a;
@@ -50,7 +50,7 @@
          8: return
       LocalVariableTable:
         Start  Length  Slot  Name   Signature
-            1       7     1 foo$macro$1   I
+            1       7     1 foo$macro$2   I
             0       9     0  this   Ldemo/a;
       LineNumberTable:
         line 5: 0
```
