-- ordered table view

local stage = display.getCurrentStage()

local enterFrameEnabled = false
local headers = {}

local function compare(a, b)
    return a.y < b.y
end

function headers:add(header)
    local parent = header.scrollView._view
    for i = 1, #headers do
        if (headers[i].parent == parent) then
            local list = headers[i].list
            for t = 1, #list do
                if (list[t] == header) then
                    return
                end
            end
            list[#list + 1] = header
            table.sort(list, compare)
            return
        end
    end
    headers[#headers + 1] = { parent = parent, list = { header } }
    if (not enterFrameEnabled) then
        Runtime:addEventListener("enterFrame", headers)
        enterFrameEnabled = true
    end
end

function headers:remove(header)
    local parent = header.scrollView._view
    for i = 1, #headers do
        if (headers[i].parent == parent) then
            local list = headers[i].list
            for t = 1, #list do
                if (list[t] == header) then
                    table.remove(list, t)
                    break
                end
            end
            if (#list == 0) then
                table.remove(headers, i)
            end
            break
        end
    end
    if (#headers == 0) then
        Runtime:removeEventListener("enterFrame", enterFrame)
        enterFrameEnabled = false
    end
end

local function enterFrameList(headers)
    if (#headers > 0) then
        local index, top = nil, 0 - headers[1].scrollView._view.y

        for i = 1, #headers do
            local itemy = headers[i].item.y
            if (index == nil and itemy - top >= 0) then
                index = i
            end
            headers[i].y = itemy
            headers[i].alpha = 0
        end

        if (index == nil) then
            headers[#headers].y = top
            headers[#headers].alpha = 1
            return
        end

        if (index) then
            local header = headers[index]
            header.alpha = 1

            if (index > 1) then
                local previous = headers[index - 1]
                previous.alpha = 1

                local gap = header.y - top
                local height = previous.item.itemHeight
                if (gap > height) then
                    previous.y = top
                else
                    previous.y = header.y - height
                end
            end
        end
    end
end

function headers:enterFrame()
    for i = 1, #headers do
        enterFrameList(headers[i].list)
    end
end


--[[
	Description:
		List item to be used in a ScrollView.
		OrderedItems will allow dragging and keep themselves tidy.
	Params:
		.group = the display group to use as a reordered item
		.listname = the name of this collection of ordered items
		.index = index of this item in the list
		.itemWidth, .itemHeight = dimensions of the item
		.scrollView = the scroll view this item is being added to
		.dragTab = display object used to show the element which instigates dragging
		.delTab = display object used to delete the element which instigates removeSelf()
		.isLocked = true for when this item cannot be reordered (regardless of showTab value)
		.dragStarted = callback function for when a drag operation has started
		.dragCompleted = callback function for when a drag operation has completed
		.itemMoved = callback function for when a drag operation has caused an item to be moved
		.header = transparent shadow of the locked row (only) to be used when the section header reaches the top
	Returns:
		Self-ordering display group.
]] --
function newOrderedItem(params)
    local group = params.group
    group.class = "ordereditem"
    group.params = params

    -- set editable values
    group.listname = params.listname -- name of the collection this item belongs to
    group.dragTab = params.dragTab -- display object to use as drag tab
    group.isLocked = params.isLocked -- true to force this item not to move
    group.index = params.index -- position of this item in the scrollView
    group.itemWidth, group.itemHeight = params.itemWidth, params.itemHeight
    group.header = params.header -- header row in the display group above

    -- if this row is a genuine header row, add it to the list
    if (group.isLocked and group.header) then
        group.header.scrollView = params.scrollView
        group.header.item = group
        headers:add(group.header)
    end

    local function calcIndexFromY(top, y, rowHeight, maxIndex)
        y = y - top
        local index = math.round(y / rowHeight) + 1
        if (index < 1) then return 1 end
        if (index > maxIndex) then return maxIndex end
        return index
    end

    local tran = nil
    function group:setPos(index, speed)
        if (group.index ~= index) then
            if (tran) then
                transition.cancel(tran)
                tran = nil
            end
            tran = transition.to(group, { time = speed or 350, y = group.minScroll + (index - 1) * params.itemHeight, onComplete = function() tran = nil end })
            group.index = index
        end
    end

    function group:evalPositions()
        local index = calcIndexFromY(group.minScroll, group.y, params.itemHeight, group.itemCount)
        local offset = 0

        for i = 1, group.parent.numChildren do
            if (group.parent[i] ~= group) then
                if (group.parent[i].class ~= "ordereditem" or group.parent[i].listname ~= group.listname) then
                    offset = offset + 1
                else
                    if (i - offset < index) then
                        group.parent[i]:setPos(i - offset)
                    elseif (i - offset >= index) then
                        group.parent[i]:setPos(i - offset + 1)
                    end
                end
            end
        end
    end

    -- updates this item's view of it's parent list (item count, total list height, etc.)
    function group:refreshListData()
        local minscroll, maxscroll = 1000000000, 0
        local itemcount = 0
        local listheight = 0

        for i = 1, group.parent.numChildren do
            local item = group.parent[i]
            if (item.class == "ordereditem" and item.listname == group.listname) then
                itemcount = itemcount + 1
                listheight = listheight + item.params.itemHeight
                if (item.y < minscroll) then minscroll = item.y end
                if (item.y + item.params.itemHeight > maxscroll) then maxscroll = item.y + item.params.itemHeight end
            end
        end

        group.minScroll, group.maxScroll = minscroll, maxscroll
        group.itemCount = itemcount
        group.listHeight = listheight
        group.scrollViewContentHeight = params.scrollView._view.height
    end

    function group:refreshGroup()
        for i = 1, group.parent.numChildren do
            local item = group.parent[i]
            if (item.class == "ordereditem" and item.listname == group.listname) then
                item:refreshListData()
            end
        end
    end

    local posTimer = nil
    local posSpeed = 0
    local prev, offset = nil, nil

    function group:setGroupY()
        if (prev and offset) then
            local n = nil -- disposable value
            n, group.y = group.parent:contentToLocal(0, prev.y - offset.y)
        end
    end

    local function cancelPosTimer()
        if (posTimer) then
            timer.cancel(posTimer)
            posTimer = nil
        end
        timerEvent = nil
        posSpeed = 0
    end

    local function updateScroll()
        local inc = posSpeed / 10
        params.scrollView._view.y = params.scrollView._view.y + inc

        if (params.scrollView._view.y > 0) then
            params.scrollView._view.y = 0
        elseif (params.scrollView._view.y + group.scrollViewContentHeight <= params.scrollView.widgetHeight) then
            params.scrollView._view.y = params.scrollView.widgetHeight - group.scrollViewContentHeight
        end

        group:setGroupY()
        group:evalPositions()
    end

    local function setPosTimer()
        local x, y = params.scrollView:getContentPosition()

        local groupY = group.y + y
        local groupTopY = groupY + params.itemHeight

        posSpeed = 0

        if (groupY < params.itemHeight) then
            posSpeed = params.itemHeight - groupY
            print(".scrollView.widgetHeight" .. params.scrollView.widgetHeight)
        elseif (groupTopY > params.scrollView.height - params.itemHeight) then
            print(".scrollView.widgetHeight" .. params.scrollView.widgetHeight)
            print("params.itemHeight"..params.itemHeight)
            print("params.scrollView.height"..params.scrollView.height)
            print("groupTopY"..groupTopY)
            posSpeed = -(params.itemHeight - (params.scrollView.widgetHeight - groupTopY))
        end

        if (posSpeed == 0) then
            cancelPosTimer()
        else
            if (posTimer == nil) then
                posTimer = timer.performWithDelay(10, updateScroll, 0)
            end
        end
    end

    -- only adds a drag listening if there is a dragtab and the row is not locked
    if (params.dragTab and not params.isLocked) then

        params.dragTab.touchBegan = function(e)
            group:refreshListData() -- ADDED!
            e.target = group
            params.dragStarted(e)
            e.target.parent:insert(e.target)
            prev = e
            local x, y = group:contentToLocal(e.x, e.y)
            offset = { x = x, y = y }
        end

        params.dragTab.touchMoved = function(e)
            group:setGroupY()
            e.target = group
            group:evalPositions()
            prev = e
            setPosTimer()
            params.itemMoved(e)
        end

        params.dragTab.touchEnded = function(e)
            group:setGroupY()

            local function complete()
                e.target = group

                for i = 1, group.parent.numChildren do
                    if (group.parent[i].class == "ordereditem" and group.parent[i].listname == group.listname) then
                        if (group.parent[i].index == group.index - 1) then
                            e.target.parent:insert(i + 1, group)
                            break
                        elseif (group.parent[i].index == group.index + 1) then
                            e.target.parent:insert(i, e.target)
                            break
                        end
                    end
                end
                group:refreshListData()

                params.dragCompleted(e)
            end

            group.index = calcIndexFromY(group.minScroll, group.y, params.itemHeight, group.itemCount)
            local y = (group.index - 1) * params.itemHeight
            transition.to(group, { time = 250, y = group.minScroll + y, onComplete = complete })
            prev = nil
            cancelPosTimer()
        end

        local function touch(e)
            if (not e.target.hasFocus and e.phase == "began") then
                stage:setFocus(e.target, e.id)
                e.target.hasFocus = true
                if (e.target.touchBegan) then e.target.touchBegan(e) end
                return true
            elseif (e.target.hasFocus) then
                if (e.phase == "moved") then
                    if (e.target.touchMoved) then e.target.touchMoved(e) end
                else
                    stage:setFocus(e.target, nil)
                    e.target.hasFocus = false
                    if (e.target.touchEnded) then e.target.touchEnded(e) end
                end
                return true
            end
            return false
        end

        params.dragTab:addEventListener("touch", touch)
    end

    -- replace the removeSelf function and shuffle the other items into position
    local removeself = group.removeSelf
    group.removeSelf = function(self)
        group.parent:removeEventListener("setEditMode", group)
        group:refreshListData()
        group:setPos(group.itemCount, 1)
        group.parent:insert(group)
        if (group.header) then headers:remove(group.header) end
        timer.performWithDelay(10, function()
            group:evalPositions()
            timer.performWithDelay(360, function()
                group:refreshGroup()
                removeself(self)
            end, 1)
        end, 1)
    end

    -- listen to the parent display group for show/hide tab events
    function group:setEditMode(e)
        -- show/hide the drag tab
        if (params.dragTab and not params.isLocked) then
            if (e.isEditEnabled) then
                transition.to(params.dragTab, { time = 350, alpha = 1 })
            else
                transition.to(params.dragTab, { time = 350, alpha = 0 })
            end
        end
        -- show/hide the delete button
        if (params.delTab) then
            if (e.isEditEnabled) then
                transition.to(params.delTab, { time = 350, alpha = 1 })
            else
                transition.to(params.delTab, { time = 350, alpha = 0 })
            end
        end

        if (group.parent) then group:refreshListData() end
    end

    params.scrollView._view:addEventListener("setEditMode", group)

    group:refreshListData()
    return group
end
