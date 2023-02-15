find seeds that have all of the gysers using <https://toolsnotincluded.net/map-tools/map-browser>

```js
let mapbrowser_cache_geyser_types = JSON.parse(sessionStorage.getItem('mapbrowser-cache-geyser-types'));
let rules = mapbrowser_cache_geyser_types.map(function(o, i){
return `rules[${i}].value=1&rules[${i}].comparator=AtLeast&rules[${i}].type=Cluster&rules[${i}].groupId=${i}&rules[${i}].id=${i}&rules[${i}].itemType=Geyser&rules[${i}].item=${o.key}`
});
copy("https://api.toolsnotincluded.net/api/maps/filtered?page=1&pageSize=20&clusterKey=expansion1::clusters/MiniClusterRadioactiveOceanStart&expansion=SpacedOut&"+rules.join('&'));
```
