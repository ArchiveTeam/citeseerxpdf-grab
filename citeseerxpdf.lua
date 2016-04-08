dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')

local downloaded = {}
local addedtolist = {}
local goodurls = {}
local seeds = {}
local secondseeds = {}
local thirdseeds = {}

local status_code = nil
local maindomains = {}

for seed in io.open("seeds", "r"):lines() do
  seeds[seed] = true
  print(string.match(string.match(seed, "^[hH][tT][tT][pP][sS]?://([^/]+)"), "([^%.]+%.[^%.:]*):?[^%.:]*$"))
  maindomains[string.match(string.match(seed, "^[hH][tT][tT][pP][sS]?://([^/]+)"), "([^%.]+%.[^%.:]*):?[^%.:]*$")] = true
end

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if seeds[parent["url"]] == true then
    secondseeds[url] = true
  elseif secondseeds[parent["url"]] == true then
    thirdseeds[url] = true
  elseif thirdseeds[parent["url"]] == true then
    goodurls[url] = true
  end
 
  if downloaded[url] ~= true and addedtolist[url] ~= true then
    addedtolist[url] = true
    return true
  else
    return false
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla)
    local origurl = url
    local url = string.match(urla, "^([^#]+)")
    if seeds[origurl] == true then
      secondseeds[url] = true
      secondseeds[string.gsub(url, "&[aA][mM][pP];", "&")] = true
    end
    if secondseeds[origurl] == true then
      thirdseeds[url] = true
      thirdseeds[string.gsub(url, "&[aA][mM][pP];", "&")] = true
    end
    if thirdseeds[origurl] == true then
      goodurls[url] = true
      goodurls[string.gsub(url, "&[aA][mM][pP];", "&")] = true
    end
    if downloaded[url] ~= true and addedtolist[url] ~= true then
      if string.match(url, "&[aA][mM][pP];") then
        table.insert(urls, { url=url })
        table.insert(urls, { url=string.gsub(url, "&[aA][mM][pP];", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&[aA][mM][pP];", "&")] = true
      elseif not (string.match(url, "<") or string.match(url, ">")) then
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^[hH][tT][tT][pP][sS]?://") then
      check(newurl)
    elseif string.match(newurl, "^[hH][tT][tT][pP][sS]?:\\/\\/") then
      check(string.gsub(newurl, "\\/", "/"))
    elseif string.match(newurl, "^%./.+") then
      if string.match(url, "^https?://.+/") then
        check(string.match(url, "^([hH][tT][tT][pP][sS]?://.+/)")..string.match(newurl, "^%./(.+)"))
      else
        check(string.match(url, "^([hH][tT][tT][pP][sS]?://.+)")..string.match(newurl, "^%.(/.+)"))
      end
    elseif string.match(newurl, "^//") then
      check("http:"..newurl)
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^([hH][tT][tT][pP][sS]?://[^/]+)")..newurl)
    elseif string.match(newurl, "^%.%./") then
      tempurl = url
      tempnewurl = newurl
      while string.match(tempnewurl, "^%.%./") do
        if not string.match(tempurl, "^[hH][tT][tT][pP][sS]?://[^/]+/$") then
          tempurl = string.match(tempurl, "^(.*/)[^/]*/")
        end
        tempnewurl = string.match(tempnewurl, "^%.%./(.*)")
      end
      check(tempurl..tempnewurl)
    elseif string.match(newurl, '=[hH][tT][tT][pP][sS]?://') then
      check(string.match(newurl, '=([hH][tT][tT][pP][sS]?://.+)'))
    end
  end

  local function checknewshorturl(newurl)
    if not (string.match(newurl, "^[hH][tT][tT][pP][sS]?://") or string.match(newurl, "^/") or string.match(newurl, "^%.%./") or string.match(newurl, "^[jJ][aA][vV][aA][sS][cC][rR][iI][pP][tT]:") or string.match(newurl, "^[mM][aA][iI][lL][tT][oO]:") or string.match(newurl, "^%${")) then
      check(string.match(url, "^([hH][tT][tT][pP][sS]?://.+/)")..newurl)
    end
  end

  check(string.match(url, "^([hH][tT][tT][pP][sS]?://[^/]+)")..'/robots.txt')
  
  if status_code ~= 404 and ((goodurls[url] == true and string.match(url, 'aaai%.org')) or seeds[url] == true or secondseeds[url] == true) then
    html = read_file(file)
    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">([^<]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, '[hH][rR][eE][fF]="([^"]+)') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, "[hH][rR][eE][fF]='([^']+)") do
      checknewshorturl(newurl)
    end
    if string.match(url, "%?") then
      checknewurl(string.match(url, "^([hH][tT][tT][pP][sS]?://[^%?]+)%?"))
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if string.gsub(".", "%.", "%%%.") ~= "%." then
    return wget.actions.ABORT
  end

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 400 and status_code ~= 403 and status_code ~= 404) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    if url["url"] == 'http://www./' or url["url"] == 'https://ssl./' then
      return wget.actions.EXIT
    end
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      print(string.match(string.match(url["url"], "^[hH][tT][tT][pP][sS]?://([^/]+)"), "([^%.]+%.[^%.:]*):?[^%.:]*$"))
      if maindomains[string.match(string.match(url["url"], "^[hH][tT][tT][pP][sS]?://([^/]+)"), "([^%.]+%.[^%.:]*):?[^%.:]*$")] == true and not err == "HOSTERR" then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
