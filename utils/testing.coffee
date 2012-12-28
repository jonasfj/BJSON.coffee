
# Inspired by
# http://blogs.adobe.com/webplatform/2012/09/10/crowdsourcing-a-feature-support-matrix-using-qunit-and-browserscope/

window._bTestResults = null

compare = (e1, e2) ->
  return true       if e1 == e2
  if e1 instanceof Array or e2 instanceof Array
    return false    if not (e1 instanceof Array and e2 instanceof Array)
    return false    if e1.length != e2.length
    for i in [0...e1.length]
      return false  if not compare(e1[i], e2[i])
    return true
  if typeof e1 is 'object' or typeof e2 is 'object'
    return false    if not (typeof e1 is 'object' and typeof e2 is 'object')
    keys = [k for k, v of e1]
    return false      if not compare(keys, [k for k, v of e2])
    for key in keys
      return false  if not compare(e1[key], e2[key])
    return true
  return false


# Don't run QUnit tests on start
QUnit.config.autostart = false

allTests = []
$ ->
  allTests = (t for t, j of testData).sort()
  for t in allTests
    json = testData[t]
    do (t, json) ->
      test t, ->
        bjson = BJSON.serialize(json)
        json2 = BJSON.parse(bjson)
        ok compare(json, json2), "Original JSON object matches serialized and parsed JSON object"
  $("#run-tests").click     -> QUnit.start()
  $("#show-qunit").click    ->
    $("#qunit").show()
    $("#show-qunit").hide()
  fetchResults()

# After each test
QUnit.testDone ({name, failed, passed, total}) ->
  window._bTestResults[name] = if failed is 0 and passed is total then 1 else 0

# Before running all tests
QUnit.begin ->
  window._bTestResults = {}

# After running all tests
QUnit.done ->
  if _bTestResults?
    appendScript "http://www.browserscope.org/user/beacon/#{_bTestKey}"
  $("#show-qunit").show()
  $("#run-test-msg").hide()

# Append a script to body
appendScript = (src) ->
  firstScript = document.getElementsByTagName('script')[0]
  newScript = document.createElement 'script'
  newScript.src = src;
  firstScript.parentNode.insertBefore(newScript, firstScript)

# Fetch Results
fetchResults = (v = 1) -> 
  appendScript "http://www.browserscope.org/user/tests/table/#{_bTestKey}?v=#{v}&o=json&callback=_fetchedResults"

@_fetchedResults = ({category_name, v, results}) ->
  # Find all tests in the results
  succ = (result, inconsistent) ->
    if result
      "<span class='label icon-ok'> Passed</span>"
    else if inconsistent
      "<span class='label label-warning icon-remove'> Inconsistent</span>"
    else
      "<span class='label label-inverse icon-remove'> Failed</span>"
  table = $("<table class='table table-hover'></table>")
  for browser, {count, summary_score, results: tests} of results
    supported = true
    inconsistent = false
    data = "Results from #{count} runs with a success rate of #{summary_score}%"
    data += "<div style='height: 500px; overflow: auto;'><table class='table table-condensed'>"
    for test in allTests
      bad = ("" + (tests[test]?.result or "0")) != "1"
      supported = supported and not bad
      unknown = bad and (not tests[test]? or tests[test]?.result isnt "0")
      if unknown
        inconsistent = true
      data += "<tr><th>#{test}</th><td>#{succ(not bad, unknown)}</td></tr>"
    data += "</table></div>"
    tr = $("<tr style='cursor: pointer;'><th>#{browser}</th><td>#{succ(supported, inconsistent)}</td></tr>")
    table.append(tr)
    tr.attr tabindex: -1
    tr.css "outline", "none"
    tr.popover
      trigger:    'focus'
      html:       true
      placement:  'left'
      title:      "Results for #{browser}"
      content:    data
  $("#results").html("")
  $("#results").append(table)

