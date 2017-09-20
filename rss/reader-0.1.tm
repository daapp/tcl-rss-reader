# based on http://wiki.tcl.tk/12801


package require snit
package require http
package require tdom


if {![catch {package require autoproxy}]} {
    autoproxy::init
}


snit::type rss::reader {
    variable url
    variable document
    variable xpath -array {}
    variable channel
    variable items

    option -command -default ""
    option -url -default ""

    constructor {args} {
        set items [list]
        $self configurelist $args
        $self Reload
    }

    method update {} {
        $self Reload
    }

    method url {} {
        return $url
    }

    method Reload {} {
        if {$options(-command) eq ""} {
            set id [http::geturl $options(-url)]
            $self ParseFeed $id
        } else {
            http::geturl $options(-url) -command [mymethod ParseFeed]
        }
    }


    method ParseFeed {id} {
        set document [dom parse [http::data $id]]

        set root [$document documentElement]

        switch -- [getRSSVersion $document] {
            0.91 - 0.92 - 0.93 - 2.0 {
                array set xpath {
                    titleXpath       /rss/channel/title/text()
                    linkXpath        /rss/channel/link/text()
                    imgNodeXpath     /rss/channel/image/title
                    imgTitleXpath    /rss/channel/image/title/text()
                    imgLinkXpath     /rss/channel/image/url/text()
                    imgWidthXpath    /rss/channel/image/width/text()
                    imgHeightXpath   /rss/channel/image/height/text()
                    storiesXpath     /rss/channel/item
                    itemTitleXpath   title/text()
                    itemLinkXpath    link/text()
                    itemPubDateXpath pubDate/text()
                    itemDescXpath    description/text()
                }
            }
            1.0 {
                array set xpath {
                    titleXpath       /rdf:RDF/*[local-name()='channel']/*[local-name()='title']/text()
                    linkXpath        /rdf:RDF/*[local-name()='channel']/*[local-name()='link']/text()
                    imgNodeXpath     /rdf:RDF/*[local-name()='image']
                    imgTitleXpath    /rdf:RDF/*[local-name()='image']/*[local-name()='title']/text()
                    imgLinkXpath     /rdf:RDF/*[local-name()='image']/*[local-name()='url']/text()
                    imgWidthXpath    /rdf:RDF/*[local-name()='image']/*[local-name()='width']/text()
                    imgHeightXpath   /rdf:RDF/*[local-name()='image']/*[local-name()='height']/text()
                    storiesXpath     /rdf:RDF/*[local-name()='item']
                    itemTitleXpath   *[local-name()='title']/text()
                    itemLinkXpath    *[local-name()='link']/text()
                    itemPubDateXpath *[local-name()='pubDate']/text()
                    itemDescXpath    *[local-name()='description']/text()
                }
            }
            default {
                error "Unsupported schema [getRSSVersion $document]"
            }
        }

        $self ParseChannel [$root child 1 channel]

        $self ParseItems [$root selectNodes $xpath(storiesXpath)]
        if {$options(-command) ne ""} {
            uplevel #0 $options(-command)
        }
    }

    method ParseChannel {node} {
        set channel [dict create]
        foreach {key fun path} {
            title nodeText titleXpath
            link nodeUri linkXpath
            {image link} nodeUri imgLinkXpath
            {image title} nodeText imgTitleXpath
            {image width} nodeText imgWidthXpath
            {image height} nodeText imgHeightXpath
        } {
            dict set channel {*}$key [$fun $node $xpath($path)]
        }
    }

    method channel {args} {
        dict get $channel {*}$args
    }

    method ParseItems {nodes} {
        set items [list]

        foreach node $nodes {
            set item [dict create]
            foreach {key fun path} {
                title nodeText itemTitleXpath
                link nodeText itemLinkXpath
                description nodeText itemDescXpath
                pubDate nodeText itemPubDateXpath
            } {
                dict set item {*}$key [$fun $node $xpath($path)]
            }
            lappend items $item
        }
    }

    method items {} {
        return $items
    }

    method item {index args} {
        dict get [lindex $items $index] {*}$args
    }

    proc nodeText {node xpath} {
        expr {[$node selectNode $xpath] ne "" ? [[$node selectNode $xpath] nodeValue] : ""}
    }

    proc nodeUri {node xpath} {
        expr {[$node selectNode $xpath] ne "" ? [encUri [[$node selectNode $xpath] nodeValue]] : ""}
    }

    proc encText {text} {
        string map { & &amp;  < &lt;  > &gt; } $text
    }

    proc encUri {uri} {
        string map { & %26; } $uri
    }

    proc getRSSVersion {document} {
        set root [$document documentElement]
        switch -- [$root nodeName] {
            rss {
                if {[$root hasAttribute version]} {
                    return [$root getAttribute version]
                } else {
                    return 0.92
                }
            }
            rdf:RDF {
                return 1.0
            }
            default {
                return 0
            }
        }
    }
}
