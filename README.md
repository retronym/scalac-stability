# Unstable compiler output

| Name | Description |
----------------------
| [lambdalift](fresh)   | Type completion can change order of typechecking methods in a class, resulting in Symbol.ids. Lambda lift places symbols-to-be-renamed in a tree set, ordered by `Symbol.isLess` (which for term symbols amounts to ordering by `Symbol.id`). |
| [macros](macros) | Macro fresh names are globally numbered, rather than per-compilation unit. |
