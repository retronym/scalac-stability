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

### Partial Function fresh names

When the typer adapts a `{ case ... => ; ...}` to `FunctionN` or `PartialFunction`, it creates fresh names for synthetic parameters. Out-of-order typechecking via type completion will change the numbering.

In general, any fresh name allocated during typer has the same problem, such as:
  - [during eta expansion](https://github.com/scala/scala/blob/9acab45aeeadef2f63da69faf81465cc15599789/src/compiler/scala/tools/nsc/typechecker/EtaExpansion.scala#L43-L46)
  - [names/defaults](https://github.com/scala/scala/blob/d50519255369bc5cee413cd6b4bc39f9c3b60be5/src/compiler/scala/tools/nsc/typechecker/NamesDefaults.scala#L173) (also [in](https://github.com/scala/scala/blob/d50519255369bc5cee413cd6b4bc39f9c3b60be5/src/compiler/scala/tools/nsc/typechecker/NamesDefaults.scala#L303))
  - converting `qual._=` to [an assignment](https://github.com/scala/scala/blob/9f0718f006a323459802804ac5aa3041c6f65e76/src/compiler/scala/tools/nsc/typechecker/Typers.scala#L4765-L4817), which creates a fresh name in [`evalOnceAll`](https://github.com/scala/scala/blob/16379739e9efa2e48eac09d046e591355fa9eb2d/src/compiler/scala/tools/nsc/ast/TreeGen.scala#L225) and `evalOnce`.
  - [Naming a local val](https://github.com/scala/scala/blob/c9d84a187a7d2f8fa486ec4902c8de28d7658e76/src/compiler/scala/tools/nsc/typechecker/SyntheticMethods.scala#L180) in synthetic equals method
  - Naming [GADT skolems](https://github.com/scala/scala/blob/5197256b44f34fa50ed468954d0bfb3bc469477d/src/compiler/scala/tools/nsc/typechecker/PatternTypers.scala#L192), which I believe can end up in inferred types of APIs stored in the pickle.

[Test Case](partial-fun) (for the `PartialFunction` case only)


```
⚡ ./test
+ mkdir -p target1 target2
+ scalac -d target1 -nowarn -Xprint:all a.scala b.scala
+ egrep -v '\.scala'
+ scalac -d target2 -nowarn -Xprint:all b.scala a.scala
+ egrep -v '\.scala'
+ diff -u /dev/fd/63 /dev/fd/62
++ show target1
++ show target2
++ egrep -v 'Classfile|checksum'
++ egrep -v 'Classfile|checksum'
+++ find target1 -name '*anonfun*.class'
+++ find target2 -name '*anonfun*.class'
++ javap -cp target2 -private -v 'target2/demo/a$$anonfun$x$1.class' 'target2/demo/a$$anonfun$y$1.class'
++ javap -cp target1 -private -v 'target1/demo/a$$anonfun$x$1.class' 'target1/demo/a$$anonfun$y$1.class'
--- /dev/fd/63  2018-01-10 13:50:20.000000000 +1000
+++ /dev/fd/62  2018-01-10 13:50:20.000000000 +1000
@@ -23,7 +23,7 @@
   #16 = Long               0l
   #18 = Utf8               applyOrElse
   #19 = Utf8               (Ljava/lang/Object;Lscala/Function1;)Ljava/lang/Object;
-  #20 = Utf8               x1
+  #20 = Utf8               x2
   #21 = Utf8               default
   #22 = Utf8
   #23 = String             #22            //
@@ -97,7 +97,7 @@
       LocalVariableTable:
         Start  Length  Slot  Name   Signature
             0      33     0  this   Ldemo/a$$anonfun$x$1;
-            0      33     1    x1   Ljava/lang/Object;
+            0      33     1    x2   Ljava/lang/Object;
             0      33     2 default   Lscala/Function1;
       LineNumberTable:
         line 5: 0
@@ -113,7 +113,7 @@
     Signature: #57                          // <A1:Ljava/lang/Object;B1:Ljava/lang/Object;>(TA1;Lscala/Function1<TA1;TB1;>;)TB1;
     MethodParameters:
       Name                           Flags
-      x1                             final
+      x2                             final
       default                        final

   public final boolean isDefinedAt(java.lang.Object);
@@ -138,7 +138,7 @@
       LocalVariableTable:
         Start  Length  Slot  Name   Signature
             0      25     0  this   Ldemo/a$$anonfun$x$1;
-            0      25     1    x1   Ljava/lang/Object;
+            0      25     1    x2   Ljava/lang/Object;
       LineNumberTable:
         line 5: 0
       StackMapTable: number_of_entries = 3
@@ -152,7 +152,7 @@
           stack = []
     MethodParameters:
       Name                           Flags
-      x1                             final
+      x2                             final

   public demo.a$$anonfun$x$1(demo.a);
     descriptor: (Ldemo/a;)V
@@ -209,7 +209,7 @@
   #16 = Long               0l
   #18 = Utf8               applyOrElse
   #19 = Utf8               (Ljava/lang/Object;Lscala/Function1;)Ljava/lang/Object;
-  #20 = Utf8               x2
+  #20 = Utf8               x1
   #21 = Utf8               default
   #22 = Utf8
   #23 = String             #22            //
@@ -283,7 +283,7 @@
       LocalVariableTable:
         Start  Length  Slot  Name   Signature
             0      33     0  this   Ldemo/a$$anonfun$y$1;
-            0      33     1    x2   Ljava/lang/Object;
+            0      33     1    x1   Ljava/lang/Object;
             0      33     2 default   Lscala/Function1;
       LineNumberTable:
         line 8: 0
@@ -299,7 +299,7 @@
     Signature: #57                          // <A1:Ljava/lang/Object;B1:Ljava/lang/Object;>(TA1;Lscala/Function1<TA1;TB1;>;)TB1;
     MethodParameters:
       Name                           Flags
-      x2                             final
+      x1                             final
       default                        final

   public final boolean isDefinedAt(java.lang.Object);
@@ -324,7 +324,7 @@
       LocalVariableTable:
         Start  Length  Slot  Name   Signature
             0      25     0  this   Ldemo/a$$anonfun$y$1;
-            0      25     1    x2   Ljava/lang/Object;
+            0      25     1    x1   Ljava/lang/Object;
       LineNumberTable:
         line 8: 0
       StackMapTable: number_of_entries = 3
@@ -338,7 +338,7 @@
           stack = []
     MethodParameters:
       Name                           Flags
-      x2                             final
+      x1                             final

   public demo.a$$anonfun$y$1(demo.a);
     descriptor: (Ldemo/a;)V
```

### Quasiquote / Reify macros

These macros use `currentFreshNameCreator`, which routes to `unit.fresh` in the compiler universe, and consequently
shares the issues with typer fresh names being unstable in the face of out-of-order type checking.

[Quasiquote Test case](macros-quasiquote)

```
⚡ ./test
+ mkdir -p target1 target2
+ scalac -d target1 -nowarn a.scala b.scala
+ scalac -d target2 -nowarn b.scala a.scala
+ diff -u /dev/fd/63 /dev/fd/62
++ show target1 demo.a
++ show target2 demo.a
++ javap -cp target1 -v demo.a
++ javap -cp target2 -v demo.a
++ egrep -v 'Classfile|checksum'
++ egrep -v 'Classfile|checksum'
--- /dev/fd/63  2018-01-11 12:56:06.000000000 +1000
+++ /dev/fd/62  2018-01-11 12:56:06.000000000 +1000
@@ -16,15 +16,15 @@
     #9 = Utf8               demo/a$$treecreator1$1
    #10 = Class              #9            // demo/a$$treecreator1$1
    #11 = Utf8               $treecreator1$1
-   #12 = Utf8               demo/a$$treecreator2$1
-   #13 = Class              #12           // demo/a$$treecreator2$1
-   #14 = Utf8               $treecreator2$1
+   #12 = Utf8               demo/a$$treecreator1$2
+   #13 = Class              #12           // demo/a$$treecreator1$2
+   #14 = Utf8               $treecreator1$2
    #15 = Utf8               demo/a$$typecreator2$1
    #16 = Class              #15           // demo/a$$typecreator2$1
    #17 = Utf8               $typecreator2$1
-   #18 = Utf8               demo/a$$typecreator4$1
-   #19 = Class              #18           // demo/a$$typecreator4$1
-   #20 = Utf8               $typecreator4$1
+   #18 = Utf8               demo/a$$typecreator2$2
+   #19 = Class              #18           // demo/a$$typecreator2$2
+   #20 = Utf8               $typecreator2$2
    #21 = Utf8               scala/reflect/api/Exprs$Expr
    #22 = Class              #21           // scala/reflect/api/Exprs$Expr
    #23 = Utf8               scala/reflect/api/Exprs
@@ -70,11 +70,11 @@
    #63 = Utf8               <init>
    #64 = Utf8               (Ldemo/a;)V
    #65 = NameAndType        #63:#64       // "<init>":(Ldemo/a;)V
-   #66 = Methodref          #10.#65       // demo/a$$treecreator1$1."<init>":(Ldemo/a;)V
+   #66 = Methodref          #13.#65       // demo/a$$treecreator1$2."<init>":(Ldemo/a;)V
    #67 = Utf8               ()Lscala/reflect/api/TypeTags$TypeTag$;
    #68 = NameAndType        #38:#67       // TypeTag:()Lscala/reflect/api/TypeTags$TypeTag$;
    #69 = Methodref          #55.#68       // scala/reflect/macros/Universe.TypeTag:()Lscala/reflect/api/TypeTags$TypeTag$;
-   #70 = Methodref          #16.#65       // demo/a$$typecreator2$1."<init>":(Ldemo/a;)V
+   #70 = Methodref          #19.#65       // demo/a$$typecreator2$2."<init>":(Ldemo/a;)V
    #71 = Utf8               apply
    #72 = Utf8               (Lscala/reflect/api/Mirror;Lscala/reflect/api/TypeCreator;)Lscala/reflect/api/TypeTags$TypeTag;
    #73 = NameAndType        #71:#72       // apply:(Lscala/reflect/api/Mirror;Lscala/reflect/api/TypeCreator;)Lscala/reflect/api/TypeTags$TypeTag;
@@ -94,8 +94,8 @@
    #87 = Utf8               Ldemo/a;
    #88 = Utf8               Lscala/reflect/macros/blackbox/Context;
    #89 = Utf8               y
-   #90 = Methodref          #13.#65       // demo/a$$treecreator2$1."<init>":(Ldemo/a;)V
-   #91 = Methodref          #19.#65       // demo/a$$typecreator4$1."<init>":(Ldemo/a;)V
+   #90 = Methodref          #10.#65       // demo/a$$treecreator1$1."<init>":(Ldemo/a;)V
+   #91 = Methodref          #16.#65       // demo/a$$typecreator2$1."<init>":(Ldemo/a;)V
    #92 = Utf8               ()V
    #93 = NameAndType        #63:#92       // "<init>":()V
    #94 = Methodref          #4.#93        // java/lang/Object."<init>":()V
@@ -124,17 +124,17 @@
         17: aload_2
         18: invokevirtual #62                 // Method scala/reflect/macros/Universe.Expr:()Lscala/reflect/api/Exprs$Expr$;
         21: aload_3
-        22: new           #10                 // class demo/a$$treecreator1$1
+        22: new           #13                 // class demo/a$$treecreator1$2
         25: dup
         26: aconst_null
-        27: invokespecial #66                 // Method demo/a$$treecreator1$1."<init>":(Ldemo/a;)V
+        27: invokespecial #66                 // Method demo/a$$treecreator1$2."<init>":(Ldemo/a;)V
         30: aload_2
         31: invokevirtual #69                 // Method scala/reflect/macros/Universe.TypeTag:()Lscala/reflect/api/TypeTags$TypeTag$;
         34: aload_3
-        35: new           #16                 // class demo/a$$typecreator2$1
+        35: new           #19                 // class demo/a$$typecreator2$2
         38: dup
         39: aconst_null
-        40: invokespecial #70                 // Method demo/a$$typecreator2$1."<init>":(Ldemo/a;)V
+        40: invokespecial #70                 // Method demo/a$$typecreator2$2."<init>":(Ldemo/a;)V
         43: invokevirtual #74                 // Method scala/reflect/api/TypeTags$TypeTag$.apply:(Lscala/reflect/api/Mirror;Lscala/reflect/api/TypeCreator;)Lscala/reflect/api/TypeTags$TypeTag;
         46: invokevirtual #77                 // Method scala/reflect/api/Exprs$Expr$.apply:(Lscala/reflect/api/Mirror;Lscala/reflect/api/TreeCreator;Lscala/reflect/api/TypeTags$WeakTypeTag;)Lscala/reflect/api/Exprs$Expr;
         49: invokeinterface #81,  1           // InterfaceMethod scala/reflect/api/Exprs$Expr.tree:()Lscala/reflect/api/Trees$TreeApi;
@@ -166,17 +166,17 @@
         17: aload_2
         18: invokevirtual #62                 // Method scala/reflect/macros/Universe.Expr:()Lscala/reflect/api/Exprs$Expr$;
         21: aload_3
-        22: new           #13                 // class demo/a$$treecreator2$1
+        22: new           #10                 // class demo/a$$treecreator1$1
         25: dup
         26: aconst_null
-        27: invokespecial #90                 // Method demo/a$$treecreator2$1."<init>":(Ldemo/a;)V
+        27: invokespecial #90                 // Method demo/a$$treecreator1$1."<init>":(Ldemo/a;)V
         30: aload_2
         31: invokevirtual #69                 // Method scala/reflect/macros/Universe.TypeTag:()Lscala/reflect/api/TypeTags$TypeTag$;
         34: aload_3
-        35: new           #19                 // class demo/a$$typecreator4$1
+        35: new           #16                 // class demo/a$$typecreator2$1
         38: dup
         39: aconst_null
-        40: invokespecial #91                 // Method demo/a$$typecreator4$1."<init>":(Ldemo/a;)V
+        40: invokespecial #91                 // Method demo/a$$typecreator2$1."<init>":(Ldemo/a;)V
         43: invokevirtual #74                 // Method scala/reflect/api/TypeTags$TypeTag$.apply:(Lscala/reflect/api/Mirror;Lscala/reflect/api/TypeCreator;)Lscala/reflect/api/TypeTags$TypeTag;
         46: invokevirtual #77                 // Method scala/reflect/api/Exprs$Expr$.apply:(Lscala/reflect/api/Mirror;Lscala/reflect/api/TreeCreator;Lscala/reflect/api/TypeTags$WeakTypeTag;)Lscala/reflect/api/Exprs$Expr;
         49: invokeinterface #81,  1           // InterfaceMethod scala/reflect/api/Exprs$Expr.tree:()Lscala/reflect/api/Trees$TreeApi;
@@ -211,9 +211,9 @@
 SourceFile: "a.scala"
 InnerClasses:
      public final #11= #10; //$treecreator1$1=class demo/a$$treecreator1$1
-     public final #14= #13; //$treecreator2$1=class demo/a$$treecreator2$1
+     public final #14= #13; //$treecreator1$2=class demo/a$$treecreator1$2
      public final #17= #16; //$typecreator2$1=class demo/a$$typecreator2$1
-     public final #20= #19; //$typecreator4$1=class demo/a$$typecreator4$1
+     public final #20= #19; //$typecreator2$2=class demo/a$$typecreator2$2
      public #25= #22 of #24; //Expr=class scala/reflect/api/Exprs$Expr of class scala/reflect/api/Exprs
      public #28= #27 of #24; //Expr$=class scala/reflect/api/Exprs$Expr$ of class scala/reflect/api/Exprs
      public #33= #30 of #32; //TreeApi=class scala/reflect/api/Trees$TreeApi of class scala/reflect/api/Trees

```