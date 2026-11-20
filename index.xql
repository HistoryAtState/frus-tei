xquery version "3.1";

module namespace idx="http://teipublisher.com/index";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace dbk="http://docbook.org/ns/docbook";

declare variable $idx:app-root :=
    let $rawPath := system:get-module-load-path()
    return
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    ;

(:~
 : Helper function called from collection.xconf to create index fields and facets.
 : This module needs to be loaded before collection.xconf starts indexing documents
 : and therefore should reside in the root of the app.
 :)
declare function idx:get-metadata($root as element(), $field as xs:string) {
    let $header := $root/tei:teiHeader
    return
        switch ($field)
            case "title" return
                string-join((
                    $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                    $header//tei:titleStmt/tei:title,
                    $root/dbk:info/dbk:title,
                    root($root)//article-meta/title-group/article-title,
                    root($root)//article-meta/title-group/subtitle
                ), " - ")
            case "author" return (
                $header//tei:correspDesc/tei:correspAction/tei:persName,
                $header//tei:titleStmt/tei:author,
                $root/dbk:info/dbk:author,
                root($root)//article-meta/contrib-group/contrib/name
            )
            case "language" return
                head((
                    $header//tei:langUsage/tei:language/@ident,
                    $root/@xml:lang,
                    $header/@xml:lang,
                    root($root)/*/@xml:lang
                ))
            case "date" return head((
                $header//tei:correspDesc/tei:correspAction/tei:date/@when,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:publicationStmt/tei:date,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:date/@when,
                $header//tei:fileDesc/tei:editionStmt/tei:edition/tei:date,
                $header//tei:publicationStmt/tei:date
            ))
            case "genre" return (
                idx:get-genre($header),
                root($root)//dbk:info/dbk:keywordset[@vocab="#genre"]/dbk:keyword,
                root($root)//article-meta/kwd-group[@kwd-group-type="genre"]/kwd
            )
            case "category" return
                (root($root)/tei:TEI/@n, "ZZZ")[1]
            case "feature" return (
                idx:get-classification($header, 'feature'),
                $root/dbk:info/dbk:keywordset[@vocab="#feature"]/dbk:keyword
            )
            case "form" return (
                idx:get-classification($header, 'form'),
                $root/dbk:info/dbk:keywordset[@vocab="#form"]/dbk:keyword
            )
            case "period" return (
                idx:get-classification($header, 'period'),
                $root/dbk:info/dbk:keywordset[@vocab="#period"]/dbk:keyword
            )
            case "content" return (
                root($root)//body,
                $root/dbk:section
            )
            case "place" return
                ($root//tei:placeName/string(), $root//tei:name[@type="place"]/string())
            case "person-id" return 
                for $id in ($root//tei:persName, $root//tei:rs[@type='person']) 
                return 
                    (if ($id/@ref) then $id/@ref/string() else (), if ($id/@key) then $id/@key/string() else ())
            case "place-id" return 
                for $id in ($root//tei:placeName, $root//tei:rs[@type='place']) 
                return 
                    (if ($id/@ref) then $id/@ref/string() else (), if ($id/@key) then $id/@key/string() else ())
            default return
                ()
};

declare function idx:get-genre($header as element()?) {
    for $target in $header//tei:textClass/tei:catRef[@scheme="#genre"]/@target
    let $category := id(substring($target, 2), doc($idx:app-root || "/data/taxonomy.xml"))
    return
        $category/ancestor-or-self::tei:category[parent::tei:category]/tei:catDesc
};

declare function idx:get-classification($header as element()?, $scheme as xs:string) {
    for $target in $header//tei:textClass/tei:catRef[@scheme="#" || $scheme]/@target
    let $category := id(substring($target, 2), doc($idx:app-root || "/data/taxonomy.xml"))
    return
        $category/ancestor-or-self::tei:category[parent::tei:category]/tei:catDesc
};
(: ==================================================================
 : FRUS search fields (hsg-jinks OP#1316).
 :
 : hsg-jinks's sitewide search filters FRUS documents by date through
 : Lucene fields on each division (frus-search-date-min/max for range
 : queries, hsg-date-min/max for fast sorting). In hsg-shell these came
 : from frus:doc-dateTime-min/max attributes stamped onto every div by a
 : preprocessing XSL (frus repo, schema/update-frus-doc-dates.xsl); the
 : v2 data model dropped those attributes, so the same derivation now
 : happens at index time: take the first dateline (outside attachments)
 : that carries a machine-readable date, low end from @from/@notBefore/
 : @when, high end from @to/@notAfter/@when, normalized to US Eastern
 : (fixed -05:00, matching hsg-shell and modules/frus-dates.xqm in
 : hsg-jinks). Divisions without dateline dates yield no field and are
 : simply invisible to date filtering, as before.
 :)

declare %private function idx:frus-first-dateline-date($div as element(tei:div), $attrs as xs:string+) as xs:string? {
    let $dates := $div//tei:dateline[not(ancestor::*[local-name() = 'attachment'])]//tei:date
    let $date := ($dates[@*[name() = $attrs and . ne '']])[1]
    return (for $attr in $attrs return $date/@*[name() = $attr][. ne ''])[1]/string()
};

declare %private function idx:frus-normalize-low($s as xs:string?) as xs:dateTime? {
    try {
        let $dt :=
            if ($s castable as xs:dateTime) then xs:dateTime($s)
            else if ($s castable as xs:date) then xs:dateTime($s || 'T00:00:00')
            else if (matches($s, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$')) then xs:dateTime($s || ':00')
            else if (matches($s, '^\d{4}-\d{2}$')) then xs:dateTime($s || '-01T00:00:00')
            else if (matches($s, '^\d{4}$')) then xs:dateTime($s || '-01-01T00:00:00')
            else ()
        return $dt ! adjust-dateTime-to-timezone(., xs:dayTimeDuration('-PT5H'))
    } catch * { () }
};

declare %private function idx:frus-normalize-high($s as xs:string?) as xs:dateTime? {
    try {
        let $dt :=
            if ($s castable as xs:dateTime) then xs:dateTime($s)
            else if ($s castable as xs:date) then xs:dateTime($s || 'T23:59:59')
            else if (matches($s, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$')) then xs:dateTime($s || ':59')
            else if (matches($s, '^\d{4}-\d{2}$')) then
                xs:dateTime($s || '-' || day-from-date(xs:date($s || '-01') + xs:yearMonthDuration('P1M') - xs:dayTimeDuration('P1D')) || 'T23:59:59')
            else if (matches($s, '^\d{4}$')) then xs:dateTime($s || '-12-31T23:59:59')
            else ()
        return $dt ! adjust-dateTime-to-timezone(., xs:dayTimeDuration('-PT5H'))
    } catch * { () }
};

declare function idx:frus-date-min($div as element(tei:div)) as xs:dateTime? {
    idx:frus-normalize-low(idx:frus-first-dateline-date($div, ("from", "notBefore", "when")))
};

declare function idx:frus-date-max($div as element(tei:div)) as xs:dateTime? {
    idx:frus-normalize-high(idx:frus-first-dateline-date($div, ("to", "notAfter", "when")))
};

(: Range-queryable string form: xs:dateTime with ':' and '-' removed,
 : e.g. 19850708T0000000500; identical to what hsg-shell stored and what
 : hsg-jinks's search.xqm builds on the query side. :)
declare function idx:frus-date-min-string($div as element(tei:div)) as xs:string? {
    idx:frus-date-min($div) ! translate(string(.), ':-', '')
};

declare function idx:frus-date-max-string($div as element(tei:div)) as xs:string? {
    idx:frus-date-max($div) ! translate(string(.), ':-', '')
};

declare function idx:frus-volume-id($div as element(tei:div)) as xs:string? {
    (root($div)//tei:teiHeader//tei:bibl[@type = 'frus-volume-id']/string(),
     root($div)/tei:TEI/@xml:id/string())[. ne ''][1]
};

declare function idx:frus-url($div as element(tei:div)) as xs:string? {
    idx:frus-volume-id($div) ! ('/historicaldocuments/' || . || '/' || $div/@xml:id)
};

declare function idx:frus-division-type($div as element(tei:div)) as xs:string? {
    root($div)//tei:teiHeader//tei:bibl[@type = 'frus-division-type']/string()[. ne ''][1]
};
