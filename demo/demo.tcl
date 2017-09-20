#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

tcl::tm::path add ..

package require rss::reader

rss::reader tclwiki -url http://wiki.tcl.tk/rss.xml

proc showWiki {} {
    puts "[tclwiki channel title] ([tclwiki channel link])"
    puts [string repeat - 60]
    foreach story [tclwiki items] {
        puts "[dict get $story pubDate]    [dict get $story title]"
    }
}

puts "Sync:"
showWiki
puts "\n\n"
puts "Async:"

tclwiki destroy
rss::reader tclwiki -url http://wiki.tcl.tk/rss.xml -command [list apply {{args} {
    showWiki
    set ::forever 1
}}]

vwait forever
