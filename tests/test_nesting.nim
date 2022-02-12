import unittest
import rapunzel

proc getHtmlContentsFromAssetsNesting (name: string): string =
  block:
    let
      path = "tests/assets/nesting/" & name & ".html"
      file = open(path, fmRead)
    defer:
      file.close()
    result = file.readAll()

test "inline-nest command":
  const rapunzelNest1 = "Hello, [* [/ Rapunzel]]!"
  const rapunzelNest2 = "Hello, [~ [* [/ Rapunzel]]]!"
  check rapunzelNest1.rapunzelParse.astToHtml() == getHtmlContentsFromAssetsNesting("inline-nest1")
  check rapunzelNest2.rapunzelParse.astToHtml() == getHtmlContentsFromAssetsNesting("inline-nest2")

test "block command including newline":
  const rapunzel = """
{*
	Header1
}
"""
  check rapunzel.rapunzelParse.astToHtml() == getHtmlContentsFromAssetsNesting("inc-nl-block1")

test "block-inline-nest command":
  const rapunzel = """
{*
	[/ Header1]
}
"""
  check rapunzel.rapunzelParse.astToHtml() == getHtmlContentsFromAssetsNesting("block-inline-nest1")

test "inline-nest command including newline":
  const rapunzel = """
{* Hello, Rapunzel!}
 [* Rapunzel] is a markup language for writing blogs that aims to provide not only the syntax expressible in Markdown, but also the ability to interpret [* [_ Nim expressions]] and handle customizable designs.
"""
  check rapunzel.rapunzelParse.astToHtml() == getHtmlContentsFromAssetsNesting("inline-nest-nl1")