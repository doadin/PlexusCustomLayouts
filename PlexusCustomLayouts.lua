local L = select(2, ...).L

local SUPPORTED = { ["showRaid"]=1,["showParty"]=1,["showPlayer"]=1,["showSolo"]=1,["nameList"]=1,["groupFilter"]=1,["roleFilter"]=1,["strictFiltering"]=1,
    ["sortMethod"]=1,["sortDir"]=1,["groupBy"]=1,["groupingOrder"]=1,["maxColumns"]=1,["unitsPerColumn"]=1,["isPetGroup"]=1,["startingIndex"]=1,["noRepeat"]=1, }
local SUPPORTED_SHORT = { ["raid"]="showRaid", ["party"]="showParty", ["player"]="showPlayer", ["solo"]="showSolo", ["group"]="groupFilter", ["role"]="roleFilter",
    ["strict"]="strictFiltering", ["sort"]="sortMethod", ["dir"]="sortDir", ["order"]="groupingOrder", ["pet"]="isPetGroup" }

local BC = {} FillLocalizedClassList(BC, false) for key, value in pairs(BC) do BC[key:upper()] = value end

--[[
The simplify is:
You don't need the entire class/role name, just the start part of it :
WARLOCK or WARLOC or WARL or WL -> "WARLOCK"
MT / MA / DPS / DAM / HEAL      -> "MAINTANK" / "MAINASSIT" / "DAMAGER" / "DAMAGER" / "HEALER"
GROUP / CLASS / ROLE / RAIDROLE -> groupBy="?" (ROLE->ASSIGNEDROLE, RAIDROLE->ROLE)
INDEX / NAME / NAMELIST         -> sortMethod="?"
ASC / DESC                      -> sortDir="?"
STRICT                          -> strictFiltering="true"
5/2                             -> unitsPerColumn="5";maxColumns="2"
PET                             -> isPetGroup=true
role= / order= / group= / dir=  -> roleFilter, groupingOrder, groupFilter, sortDir, also sort= / strict= / pet=
--]]

local PlexusRoster = Plexus:GetModule("PlexusRoster")
local PlexusLayout = Plexus:GetModule("PlexusLayout")
local PlexusCustomLayouts = Plexus:NewModule("PlexusCustomLayouts")
local lastLayout; --for NO REPEAT parse;

PlexusCustomLayouts.defaultDB = {
	layouts = {
		[GAMEMENU_HELP] = L.USAGE_HELP_MESSAGE, --"WARR,DK,PAL,HUN;CLASS\n\n;1,2,3,4,5;8/3;NR\n\nOneplayer",
		["CustomLayoutsExample"] = "nameList=Myraidleader,"..UnitName("player")..",Mylover;sort=NAMELIST\n"
		.."groupFilter=TANK;groupBy=CLASS;order=WARR,PAL;sort=NAME\n"
		.."HEALER,MA;groupBy=RAIDROLE;sort=INDEX;DESC\n"
		.."1,2,3,4,5,6,7,8;NOREPEAT;INDEX;ASC;5/8\n"
		.."1,2,3,4,5,6,7,8;PET;5/2\n",
    }
}


local options = {
	type = "execute",
	name = L["Custom Layouts"],
	desc = L["Add customed layouts using a simple grammer."],
	order = 10,
	func = function()
        --if InterfaceOptionsFrame:IsVisible() then
        --    InterfaceOptionsFrame.lastFrame = nil
        --    HideUIPanel(InterfaceOptionsFrame, true)
        --    PlexusCustomLayoutsFrame.lastFrame = InterfaceOptionsFrame
        --else
        --    LibStub("AceConfigDialog-3.0"):Close("Plexus")
        --    PlexusCustomLayoutsFrame.lastFrame = function() LibStub("AceConfigDialog-3.0"):Open("Plexus") end
        --end

		--PlexusLayout:SaveLayout("aa", { {groupFilter = "PALADIN",},{groupFilter = "SHAMAN",},{groupFilter = "MAGE",} });
		PlexusCustomLayoutsFrame:Show()
		local layoutName
		if PlexusLayout.db.profile.layouts.force and PlexusLayout.db.profile.layouts.force~= Plexus.L["None"] then
			layoutName = PlexusLayout.db.profile.layouts.force
		else
			local party_type = PlexusRoster:GetPartyState()
			layoutName = PlexusLayout.db.profile.layouts[party_type]
		end

		if ( PlexusCustomLayouts.db.profile.layouts and PlexusCustomLayouts.db.profile.layouts[layoutName] ) then
			PlexusCustomLayouts_SelectLayout(layoutName)
		else
			PlexusCustomLayouts_SelectFirstLayout()
		end
		PlexusCustomLayouts_UpdateFrame()
		GameTooltip:Hide()
	end
}

PlexusCustomLayouts.options = { type = "group", name = options.name, order = options.order, args = { button = options } }

function PlexusLayout:SaveLayout(layoutName, layout)
	if(self.layoutSettings[layoutName]) then
		self.layoutSettings[layoutName] = layout
	else
		self:AddLayout(layoutName, layout)
	end

	if self.db.profile.layouts.force then
		self.db.profile.layouts.force = layoutName
		DEFAULT_CHAT_FRAME:AddMessage(format(L["PlexusCustomLayouts: % saved and loaded as %s layout."], layoutName, "FORCE"), 1, 1, 0);
		self:ReloadLayout()
	else
		local party_type = PlexusRoster:GetPartyState()
		self.db.profile.layouts[party_type] = layoutName
		DEFAULT_CHAT_FRAME:AddMessage(format(L["PlexusCustomLayouts: % saved and loaded as %s layout."], layoutName, party_type), 1, 1, 0);
		self:ReloadLayout()
	end
end

function PlexusLayout:RemoveLayoutValidate(party_type, layoutName)
	local options = self.options.args[party_type .. "layout"]
	if options then
		self.options.args[party_type .. "layout"].values[layoutName]=nil
	end
end

function PlexusLayout:DeleteLayout(layoutName)
	self.layoutSettings[layoutName] = false
	local party_states = {}

	for _, party_type in ipairs(PlexusRoster.party_states) do
		self:RemoveLayoutValidate(party_type, layoutName)
	end

	self:RemoveLayoutValidate("force", layoutName)

	if self.db.profile.layouts.force and self.db.profile.layouts.force==layoutName  then
		self.db.profile.layouts.force = Plexus.L["None"]
	else
		local party_type = PlexusRoster:GetPartyState()
		if self.db.profile.layouts[party_type] == layoutName then
			self.db.profile.layouts[party_type] = Plexus.L["None"]
		end
	end

	self:ReloadLayout();
end

--Hook
PlexusLayout.OnEnableOrigin = PlexusLayout.OnEnable
function PlexusLayout:OnEnable()
	if PlexusCustomLayouts and PlexusCustomLayouts.db then
		for k, v in pairs( PlexusCustomLayouts.db.profile.layouts ) do
            if k ~= GAMEMENU_HELP then
			    local layout = PlexusCustomLayouts_ConvertLayout(v)
			    PlexusLayout:AddLayout(k, layout)
            end
		end
	end
	PlexusLayout:OnEnableOrigin()
	PlexusLayout:UnregisterMessage("Plexus_RosterUpdated")
	PlexusLayout:RegisterMessage("Plexus_RosterUpdated", "LayoutUpdateWhenRosterUpdated")
	PlexusLayout:RegisterEvent("PLAYER_ROLES_ASSIGNED", "LayoutUpdateWhenRosterUpdated")
end

--HOOK the PlexusLayout:LoadLayout
PlexusLayout.LoadLayoutOrigin = PlexusLayout.LoadLayout
function PlexusLayout:LoadLayout(layoutName)
	lastLayout = nil;
	local oldLayout = PlexusLayout.layoutSettings[layoutName]
	if type(oldLayout) ~= "table" or not next(oldLayout) then
		PlexusLayout:LoadLayoutOrigin(layoutName)
	else
		PlexusLayout.layoutSettings[layoutName] = PlexusCustomLayouts_ParseNoRepeatLayout(oldLayout)
		lastLayout = PlexusLayout.layoutSettings[layoutName];
		--DEFAULT_CHAT_FRAME:AddMessage("loaded size="..#lastLayout)
		PlexusLayout:LoadLayoutOrigin(layoutName)
		PlexusLayout.layoutSettings[layoutName] = oldLayout
	end
end

--Hook, Plexus_RosterUpdated,  check if need parse NO REPEAT;
function PlexusLayout:LayoutUpdateWhenRosterUpdated()
	local layoutName
	if self.db.profile.layouts.force and self.db.profile.layouts.force~= Plexus.L["None"] then
		layoutName = self.db.profile.layouts.force
	else
		local party_type = PlexusRoster:GetPartyState()
		layoutName = self.db.profile.layouts[party_type]
	end
	

	local layout = layoutName and PlexusLayout.layoutSettings[layoutName]
	if(layout and lastLayout) then
		--check lastLayout, which was set on last LoadLayout. 
		--RosterUpdated event dosen't load new layout, so the layout must be the same as last one.
		local idx, header;
		local needParse = false;
		for _, header in pairs(layout) do
			if header.noRepeat then needParse = true; end
		end
		if(needParse) then
			--DEFAULT_CHAT_FRAME:AddMessage("parsing layout...");
			local parsedLayout = PlexusCustomLayouts_ParseNoRepeatLayout(layout);
			local needUpdate = false;
			if(#lastLayout~=#parsedLayout) then
				--DEFAULT_CHAT_FRAME:AddMessage("cols not match, ");
				needUpdate = true;
			else
				for idx, header in pairs(parsedLayout) do
					if(parsedLayout[idx].nameList ~= lastLayout[idx].nameList) then
						needUpdate = true;
						break;
					end
				end
			end

			if( needUpdate ) then
				--DEFAULT_CHAT_FRAME:AddMessage("layout need update...");
				PlexusLayout:PartyTypeChanged()
				return
			end
		end
	end

	PlexusLayout:PartyMembersChanged()
end

local GROUP_FILTER_ABBR
if Plexus:IsRetailWow() then
    GROUP_FILTER_ABBR = {
    	[BC.WARRIOR]="WARRIOR",         ["WARRIOR"]="WARRIOR",          ["ZS"]="WARRIOR",
    	[BC.PRIEST]="PRIEST",           ["PRIEST"]="PRIEST",            ["MS"]="PRIEST",
    	[BC.DRUID]="DRUID",             ["DRUID"]="DRUID",              ["DD"]="DRUID",         ["XD"]="DRUID",
    	[BC.PALADIN]="PALADIN",         ["PALADIN"]="PALADIN",          ["QS"]="PALADIN",       ["SQ"]="PALADIN",
    	[BC.SHAMAN]="SHAMAN",           ["SHAMAN"]="SHAMAN",            ["SM"]="SHAMAN",
    	[BC.MAGE]="MAGE",               ["MAGE"]="MAGE",                ["FS"]="MAGE",
    	[BC.WARLOCK]="WARLOCK",         ["WARLOCK"]="WARLOCK",          ["WL"]="WARLOCK",       ["SS"]="WARLOCK",
    	[BC.HUNTER]="HUNTER",	        ["HUNTER"]="HUNTER",            ["LR"]="HUNTER",
    	[BC.ROGUE]="ROGUE",             ["ROGUE"]="ROGUE",              ["DZ"]="ROGUE",         ["QXZ"]="ROGUE",
    	[BC.DEATHKNIGHT]="DEATHKNIGHT", ["DEATHKNIGHT"]="DEATHKNIGHT",  ["DK"]="DEATHKNIGHT",
        [BC.MONK]="MONK",               ["MONK"]="MONK",                ["WS"]="MONK",
        [BC.DEMONHUNTER]="DEMONHUNTER", ["DEMONHUNTER"]="DEMONHUNTER",  ["DH"]="DEMONHUNTER",
    	["MAINTANK"]="MAINTANK",        ["MT"]="MAINTANK",
    	["MAINASSIST"]="MAINASSIST",    ["MA"]="MAINASSIST",
        ["HEALER"]="HEALER",            ["HEAL"]="HEALER",
        ["DAMAGER"]="DAMAGER",          ["DAM"]="DAMAGER",      ["DPS"]="DAMAGER",
        ["TANK"]="TANK",
        ["NONE"]="NONE",
    	["1"]="1", ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5", ["6"]="6", ["7"]="7", ["8"]="8",
    }
end
if Plexus:IsClassicWow() or Plexus:IsWrathWow() then
	GROUP_FILTER_ABBR = {
    	[BC.WARRIOR]="WARRIOR",         ["WARRIOR"]="WARRIOR",          ["ZS"]="WARRIOR",
    	[BC.PRIEST]="PRIEST",           ["PRIEST"]="PRIEST",            ["MS"]="PRIEST",
    	[BC.DRUID]="DRUID",             ["DRUID"]="DRUID",              ["DD"]="DRUID",         ["XD"]="DRUID",
    	[BC.PALADIN]="PALADIN",         ["PALADIN"]="PALADIN",          ["QS"]="PALADIN",       ["SQ"]="PALADIN",
    	[BC.SHAMAN]="SHAMAN",           ["SHAMAN"]="SHAMAN",            ["SM"]="SHAMAN",
    	[BC.MAGE]="MAGE",               ["MAGE"]="MAGE",                ["FS"]="MAGE",
    	[BC.WARLOCK]="WARLOCK",         ["WARLOCK"]="WARLOCK",          ["WL"]="WARLOCK",       ["SS"]="WARLOCK",
    	[BC.HUNTER]="HUNTER",	        ["HUNTER"]="HUNTER",            ["LR"]="HUNTER",
    	[BC.ROGUE]="ROGUE",             ["ROGUE"]="ROGUE",              ["DZ"]="ROGUE",         ["QXZ"]="ROGUE",
    	["MAINTANK"]="MAINTANK",        ["MT"]="MAINTANK",
    	["MAINASSIST"]="MAINASSIST",    ["MA"]="MAINASSIST",
        ["HEALER"]="HEALER",            ["HEAL"]="HEALER",
        ["DAMAGER"]="DAMAGER",          ["DAM"]="DAMAGER",      ["DPS"]="DAMAGER",
        ["TANK"]="TANK",
        ["NONE"]="NONE",
    	["1"]="1", ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5", ["6"]="6", ["7"]="7", ["8"]="8",
    }
end

local GROUP_BYS = {
    ["ROLE"] = "ASSIGNEDROLE",
    ["ASSIGNEDROLE"] = "ASSIGNEDROLE",
    ["RAIDROLE"] = "ROLE",
    ["CLASS"] = "CLASS",
    ["GROUP"] = "GROUP",
}

--if some token not a group filter, then return nil, token, is_first
local function expandABBR(str)
    local t = { strsplit(",", str) }
    for i = 1, #t do
        local v = strtrim(t[i])
        local thisIsGroup = false
        for abbr, av in pairs(GROUP_FILTER_ABBR) do
            if strsub(abbr, 1, #v)==v then --strsub("德鲁伊", 1, #"德")=="德", strsub("WARRIOR", 1, #"WARR") == "WARR"
                t[i] = av
                thisIsGroup = true
                break
            end
        end
        if not thisIsGroup then
            return nil, t[i], i==1
        end
    end
    return table.concat(t, ",")
end

function PlexusCustomLayouts_ConvertOneHeader(line)
	local header = {
		["showPlayer"] = true,
		["showSolo"] = true,
		["showParty"] = true,
		["showRaid"] = true,
	}
	local attrs = {strsplit(";", line)}
	local haveGroupFilter = false
	for i=1, #attrs do
		local attr = strtrim(attrs[i])
		if(attr=="") then
			--do nothing
		elseif(string.find(attr, "=")) then --attribute=value;
			local t = {strsplit("=", attr)}
			if(#t~=2) then
                DEFAULT_CHAT_FRAME:AddMessage("Illegal Element: "..attr, 1, 0, 0)
                return nil
            end
			t[1]=strtrim(t[1])
			t[2]=string.gsub(strtrim(t[2]), "\"", "")
            local shortMap = SUPPORTED_SHORT[strlower(t[1])]
            t[1] = shortMap or t[1]
            if not SUPPORTED[t[1]] then
                DEFAULT_CHAT_FRAME:AddMessage(format("Not supported attribute '%s'", attr), 1, 0, 0)
                return nil
            end

            if(t[1]=="groupFilter" or t[1]=="nameList") then
                if haveGroupFilter then
                    DEFAULT_CHAT_FRAME:AddMessage("Illegal Element(more than one filter): "..attr, 1,0,0)
                    return nil
                end
                haveGroupFilter = true
            end

			if(t[1]=="groupingOrder" or t[1]=="roleFilter" or t[1]=="groupFilter") then
                local groups, failed = expandABBR(t[2])
                if (groups == nil) then
                    DEFAULT_CHAT_FRAME:AddMessage(format("Only group allowed in '%s', got '%s'", attr, failed), 1, 0, 0)
                    return nil
                end
				header[t[1]] = groups
            elseif t[1]=="groupBy" then
                local groupBy = GROUP_BYS[t[2]]
                if not groupBy then
                    DEFAULT_CHAT_FRAME:AddMessage(format("Not supported groupBy type '%s'", attr), 1, 0, 0)
                    return nil
                end
                header[t[1]] = groupBy
            elseif t[1]=="showParty" or t[1]=="showRaid" or t[1]=="showSolo" or t[1]=="showPlayer" or t[1]=="strictFiltering" or t[1]=="isPetGroup" or t[1]=="noRepeat" then
				header[t[1]] = (strlower(t[2]) == "true" or t[2]=="1")  and true or false
            elseif t[1]=="unitsPerColumn" or t[1]=="maxColumns" then
                header[t[1]] = tonumber(t[2])
            else
                header[t[1]] = t[2]
            end
		elseif(string.find(attr,"/")) then --unitsPerColumn/maxColumns;
			local t = {strsplit("/", attr)}
			if(#t~=2) then
                DEFAULT_CHAT_FRAME:AddMessage(format("Illegal Element: '%s', do you mean 'unitsPerColumn/maxColumns'", attr), 1, 0, 0)
                return nil
            end
			header.unitsPerColumn = tonumber(strtrim(t[1]))
			header.maxColumns = tonumber(strtrim(t[2]))
		elseif(attr=="PET") then
			header.isPetGroup = true
		elseif(attr=="INDEX" or attr=="NAME" or attr=="NAMELIST") then
			header.sortMethod = attr
		elseif(attr=="ASC" or attr=="DESC") then
			header.sortDir = attr
		elseif(attr=="STRICT") then
			header.strictFiltering = true
		elseif(GROUP_BYS[attr]) then
			header.groupBy = GROUP_BYS[attr]
		elseif(attr=="NOREPEAT" or attr=="NOR" or attr=="NR") then
			header.noRepeat = true
		else
			--groupFilter or nameList
			if haveGroupFilter then
				DEFAULT_CHAT_FRAME:AddMessage("Illegal Element(more than one filter): "..attr, 1,0,0)
				return nil
			end
			haveGroupFilter = true;
            local groups, failed, isFirst = expandABBR(attr)
            if groups == nil then
                if not isFirst then
                    DEFAULT_CHAT_FRAME:AddMessage(format("Warning, '%s' are groups until '%s'", attr, failed),1,.5,.5)
                end
                local t = {strsplit(",", attr) }
                for i = 1, #t do
                    t[i] = strtrim(t[i])
                end
                header.nameList = table.concat(t, ",")
            else
                header.groupFilter = groups
            end
		end
	end

    --dump(header)
    if(header.groupBy and not header.groupingOrder) then header.groupingOrder = "" end --can't be nil
	return header
end
--将缩写的格式字符串转换为PlexusLayoutLayouts的格式
function PlexusCustomLayouts_ConvertLayout(text)
	text = string.gsub(text,"，", ",")
	text = string.gsub(text,"；", ";")
	text = string.gsub(text,"＝", "=")
	local lines = {strsplit("\n", strtrim(text))}
	local layout = {}
	local count = 1
	for i=1, #lines do
		lines[i] = strtrim(lines[i])
        if(lines[i]=="") then
            if(i>1 and i<#lines and lines[i-1]~="" and lines[i+1]=="") then
                layout[count] = { groupFilter="", } --a double empty line stands for a spacer
                count = count + 1
            end
        else
            lines[i] = strtrim(lines[i]:gsub("#.*$", ""))  --commented line doesn't count as spacers
            if lines[i]~="" then
                layout[count] = PlexusCustomLayouts_ConvertOneHeader(lines[i])
                if layout[count] == nil then return nil end
                count = count + 1
            end
        end
	end

	return layout
end

function PlexusCustomLayouts_ParseNoRepeatLayout(layout) --处理标记为NOREPEAT的layout, PetGroup can't use NO REPEAT
	local header, newLayout, usedName, needParse = nil, {}, {}, false;

	for _, header in pairs(layout) do
		if header.noRepeat then needParse = true break end
	end
	if not needParse then --no headers are defined as noRepeat
		return layout
	end

	--Get non-NOREPEAT headers nameList.
	for _, header in pairs(layout) do
		if not header.isPetGroup and not header.noRepeat then
			if not header.GetAttribute then
				header.GetAttribute = function(self, attr) return self[attr] end
			end

			local sortingTable = SecureGroupHeader_UpdateCopy(header)
			--[[ [1]="raid1", [2]="raid2", "raid1"="name1", "raid2"="name2" ]]

			for i=1,#sortingTable do
				usedName[sortingTable[sortingTable[i]]] = true
			end
		end
	end

	for _, header in pairs(layout) do
		if header.isPetGroup then 
			table.insert(newLayout, header)
		else
			if not header.GetAttribute then
				header.GetAttribute = function(self, attr) return self[attr] end
			end

			if not header.noRepeat then
				table.insert(newLayout, header)
			else
				local nameList = {}
				local sortingTable = SecureGroupHeader_UpdateCopy(header)
				for i=1, #sortingTable do
					if not usedName[sortingTable[sortingTable[i]]] then 
						table.insert(nameList, sortingTable[sortingTable[i]])
						usedName[sortingTable[sortingTable[i]]] = true
					end
				end
				if #nameList > 0 then
					local newHeader = {}
					for k, v in pairs(header) do
						newHeader[k] = v
					end
					newHeader.nameList = table.concat(nameList, ",")
					newHeader.groupFilter = nil
                    newHeader.groupBy = nil
					table.insert(newLayout, newHeader)
				end
			end
		end
	end
	
	--DevTools_Dump(newLayout)
	return newLayout
end

function PlexusCustomLayouts_NewLayout(name)
	if(PlexusCustomLayouts.db.profile.layouts[name]) then
		DEFAULT_CHAT_FRAME:AddMessage(L["Layout name is already used."], 1, 1, 0)
	else
		PlexusCustomLayouts.db.profile.layouts[name] = ""
		UIDropDownMenu_Initialize(PlexusCustomLayoutsFrameDropDown, PlexusCustomLayouts_DropDown_Initialize)
		PlexusCustomLayouts_SelectLayout(name)
	end
end

function PlexusCustomLayouts_SelectLayout(name)
	UIDropDownMenu_Initialize(PlexusCustomLayoutsFrameDropDown, PlexusCustomLayouts_DropDown_Initialize)
	UIDropDownMenu_SetSelectedValue(PlexusCustomLayoutsFrameDropDown, name);
	PlexusCustomLayoutsFrameArg:SetText(PlexusCustomLayouts.db.profile.layouts[name] or "")
	PlexusCustomLayouts_UpdateFrame()
end

function PlexusCustomLayouts_SelectFirstLayout()
	local name = next(PlexusCustomLayouts.db.profile.layouts)
	if name then 
		PlexusCustomLayouts_SelectLayout(name)
	else
		UIDropDownMenu_SetSelectedValue(PlexusCustomLayoutsFrameDropDown, nil);
	end
	PlexusCustomLayouts_UpdateFrame()
end
	

function PlexusCustomLayouts_DeleteLayout()
	local name = UIDropDownMenu_GetSelectedValue(PlexusCustomLayoutsFrameDropDown)
	if(name) then
		PlexusCustomLayouts.db.profile.layouts[name] = nil;
		PlexusLayout:DeleteLayout(name);
		PlexusCustomLayouts_SelectFirstLayout()
	end
end
		

--=========================================================================
-- FRAME CODE
--=========================================================================
function PlexusCustomLayoutsFrame_OnLoad(self)
	local frame = self;
	local mover = _G[frame:GetName() .. "Mover"] or CreateFrame("Frame", frame:GetName() .. "Mover", frame)
	mover:EnableMouse(true)
	mover:SetPoint("TOP", frame, "TOP", 0, 10)
	mover:SetWidth(160)
	mover:SetHeight(40)
	mover:SetScript("OnMouseDown", function(self)
		self:GetParent():StartMoving()
	end)
	mover:SetScript("OnMouseUp", function(self)
		self:GetParent():StopMovingOrSizing()
	end)
	frame:SetMovable(true)

	_G[self:GetName().."HeaderText"]:SetText(L["Custom Layouts"])
end

function PlexusCustomLayoutsFrame_NewOnClick()
	StaticPopup_Show("PLEXUS_NEW_LAYOUT")
end

function PlexusCustomLayoutsFrame_SaveOnClick()
	local layout = PlexusCustomLayouts_ConvertLayout(PlexusCustomLayoutsFrameArg:GetText())
	if layout then
		local layoutName = UIDropDownMenu_GetSelectedValue(PlexusCustomLayoutsFrameDropDown)
		PlexusCustomLayouts.db.profile.layouts[layoutName] = PlexusCustomLayoutsFrameArg:GetText()
		PlexusLayout:SaveLayout(layoutName, layout)
		PlexusCustomLayoutsFrameArg:ClearFocus()
	else
		DEFAULT_CHAT_FRAME:AddMessage(L["Layout text format error, see above information."], 1, 0, 0)
	end
end

function PlexusCustomLayoutsFrame_DeleteOnClick()
	StaticPopup_Show("PLEXUS_LAYOUT_DELETE")
end

function PlexusCustomLayoutsFrame_CancelOnClick()
    StaticPopup_Show("PLEXUS_LAYOUT_CANCEL")
end

function PlexusCustomLayouts_DropDown_Initialize()
	local info;
	local k,v;
	if PlexusCustomLayouts and PlexusCustomLayouts.db then
		for k, _ in pairs( PlexusCustomLayouts.db.profile.layouts ) do
			info = {};
			info.text = k
			info.func = PlexusCustomLayouts_DropDown_OnClick;
			info.value = k
			UIDropDownMenu_AddButton(info);
		end
	end
end

function PlexusCustomLayouts_DropDown_OnClick(self)
	PlexusCustomLayouts_SelectLayout(self.value)
end

function PlexusCustomLayouts_UpdateFrame()
	if next(PlexusCustomLayouts.db.profile.layouts) then
		PlexusCustomLayoutsFrameSave:Enable()
		PlexusCustomLayoutsFrameDelete:Enable()
		UIDropDownMenu_EnableDropDown(PlexusCustomLayoutsFrameDropDown)
	else
		PlexusCustomLayoutsFrameSave:Disable()
		PlexusCustomLayoutsFrameDelete:Disable()
		PlexusCustomLayoutsFrameArg:SetText("")
		UIDropDownMenu_DisableDropDown(PlexusCustomLayoutsFrameDropDown)
		PlexusCustomLayoutsFrameDropDownText:SetText("")
	end
	local v = UIDropDownMenu_GetSelectedValue(PlexusCustomLayoutsFrameDropDown)
	if( not v or PlexusCustomLayouts.defaultDB.layouts[v]) then
		PlexusCustomLayoutsFrameDelete:Disable()
        PlexusCustomLayoutsFrameSave:Disable()
    else
		PlexusCustomLayoutsFrameDelete:Enable()
        PlexusCustomLayoutsFrameSave:Enable()
    end
    if v and PlexusCustomLayoutsFrameArg:GetText() == PlexusCustomLayouts.db.profile.layouts[v] then
        PlexusCustomLayoutsFrameCancel:SetEnabled(false)
    else
        PlexusCustomLayoutsFrameCancel:SetEnabled(true)
    end
end

StaticPopupDialogs["PLEXUS_NEW_LAYOUT"] = {
	text = NAME,
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 24,
	OnAccept = function(self)
		PlexusCustomLayouts_NewLayout(self.editBox:GetText());
	end,
	OnShow = function(self)
		self.editBox:SetFocus();
	end,
	OnHide = function(self)
		self.editBox:SetText("");
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent();
		PlexusCustomLayouts_NewLayout(parent.editBox:GetText());
		parent:Hide();
	end,
    EditBoxOnTextChanged = function(self)
        local parent = self:GetParent();
        local text = parent.editBox:GetText() or ""
        if PlexusLayout.layoutSettings[text] then
            parent.button1:Disable();
        else
            parent.button1:Enable();
        end
    end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
};

StaticPopupDialogs["PLEXUS_LAYOUT_DELETE"] = {
	text = CALENDAR_DELETE_EVENT_CONFIRM,
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
		PlexusCustomLayouts_DeleteLayout();
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
};

StaticPopupDialogs["PLEXUS_LAYOUT_CANCEL"] = {
	text = PRODUCT_CHOICE_NO_TAKE_BACKSIES or CONFIRM_CONTINUE,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(self)
        local layoutName = UIDropDownMenu_GetSelectedValue(PlexusCustomLayoutsFrameDropDown)
        PlexusCustomLayouts_SelectLayout(layoutName)
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
};
