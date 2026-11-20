xquery version "1.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

(: store the collection configuration, and next to it the index module it imports (collection.xconf
 : refers to it there): outside the data collection, which indexing locks while documents are stored :)
declare variable $config := concat("/db/system/config", $target);

local:mkcol("/db/system/config", $target),
(: remove the index module of an earlier installation first: eXist-db refuses to store a collection
 : configuration while another document is in its collection :)
if (util:binary-doc-available(concat($config, "/index.xql"))) then xdb:remove($config, "index.xql") else (),
xdb:store-files-from-pattern($config, $dir, "*.xconf"),
xdb:store-files-from-pattern($config, $dir, "index.xql")