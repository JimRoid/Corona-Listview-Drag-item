-- Widgets2.0 ReorderScrollView

local widget = require("widget")
local storyboard = require("storyboard")
local scene = storyboard.newScene()

-- Our scene
function scene:createScene(event)
    local group = self.view
    local fListItemCount = 0

    -- create inner display groups
    local rowGrp, headerGrp = display.newGroup(), display.newGroup()

    -- definitions of the rows in the scrollView scroll view...
    -- .colour is used in the newRow() function below to help create the individual rows
    -- .isLocked states if the row can be dragged and/or deleted or not
    -- .listname is the name of the particular group of rows to be arranged (here we have two lists "B" and "D" which are separated from each other)
    -- .itemheight defines the height of the row - 0,0 of the row's display group is the top and itemheight shows where the bottom is
    -- .fontsize is used in the newRow() function below to render text
    local size = 36
    local item_height = 100
    local rows = {
        { colour = { 0.39, 0.39, 0.39 }, isLocked = true, listname = "A", itemheight = item_height + 100, fontsize = size, },
        { colour = { 1, 1, 1 }, isLocked = false, listname = "B", itemheight = item_height, fontsize = size, },
        { colour = { 1, 1, 1 }, isLocked = false, listname = "B", itemheight = item_height, fontsize = size, },
        { colour = { 1, 1, 1 }, isLocked = false, listname = "B", itemheight = item_height, fontsize = size, },
        { colour = { 1, 1, 1 }, isLocked = false, listname = "B", itemheight = item_height, fontsize = size, },
        { colour = { 1, 1, 1 }, isLocked = false, listname = "B", itemheight = item_height, fontsize = size, },
        --		{colour={100,100,100},isLocked=true,listname="C",itemheight=22,fontsize=12,},
        --		{colour={200,200,255},isLocked=false,listname="D",itemheight=44,fontsize=16,},
        --		{colour={200,200,255},isLocked=false,listname="D",itemheight=44,fontsize=16,},
        --		{colour={200,200,255},isLocked=false,listname="D",itemheight=44,fontsize=16,},
        --		{colour={200,200,255},isLocked=false,listname="D",itemheight=44,fontsize=16,},
        --		{colour={200,200,255},isLocked=false,listname="D",itemheight=44,fontsize=16,},
        --		{colour={200,200,255},isLocked=false,listname="D",itemheight=44,fontsize=16,},
        --		{colour={100,100,100},isLocked=true,listname="E",itemheight=22,fontsize=12,},
    }

    -- get this because otherwise the scrollView cannot be told how tall it's content is
    -- there is a gotcha with this because the content height may not be what you tell it to be, so expect it to be slightly more scrollable than you expect
    local totalheight = 0
    for i = 1, #rows do
        totalheight = totalheight + rows[i].itemheight
    end

    -- Create a ScrollView
    local scrollView = widget.newScrollView{
        left = 0,
        top = 0,
        id = "onBottom",
        hideBackground = true,
        horizontalScrollingDisabled = true,
        listener = scrollListener,
    }

    -- add content groups
    scrollView:insert(rowGrp)
    scrollView:insert(headerGrp)

    -- i have removed the old background image from the demo

    -- don't forget to insert objects into the scene group!
    group:insert(scrollView)

    --[[ Create the reordered items... ]] --

    local newRow, isEdit = nil, false
    local dragStarted, dragCompleted, itemMoved, delete = nil, nil, nil, nil
    local editButton, doneButton = nil, nil

    -- handle the edit button
    local function onEditRelease(event)
        transition.to(doneButton, { time = 350, alpha = 1 })
        transition.to(editButton, { time = 350, alpha = 0 })
        scrollView._view:dispatchEvent{ name = "setEditMode", target = scrollView._view, isEditEnabled = true }
        isEdit = true
    end

    -- handle the done button
    local function onDoneRelease(event)
        transition.to(editButton, { time = 350, alpha = 1 })
        transition.to(doneButton, { time = 350, alpha = 0 })

        scrollView._view:dispatchEvent{ name = "setEditMode", target = scrollView._view, isEditEnabled = false }
        isEdit = false
    end

    local titleBar_y = 68

    -- button below is local because of forward declaration defined earlier
    editButton = widget.newButton{
        width = 100,
        label = "Edit",
        fontSize = 30,
        onRelease = onEditRelease
    }
    editButton.x = _W - editButton.width * 0.5
    editButton.y = 0 + editButton.height * 0.5 -- titleBar_y - 24
    editButton.alpha = 1


    -- button below is local because of forward declaration defined earlier
    doneButton = widget.newButton{
        width = 100,
        height = 120,
        label = "Done",
        fontSize = 30,
        onRelease = onDoneRelease
    }
    doneButton.x = _W - doneButton.width * 0.5
    doneButton.y = editButton.y
    doneButton.alpha = 0

    group:insert(editButton)
    group:insert(doneButton)


    -- create list of reordereditems
    dragStarted = function(e)
        local item = e.target
        --		print('dragStarted',item.index)
        item.alpha = .5
        item.light.alpha = 1
        item.dragtab:setFillColor(0.39, 0.39, 0.39)
    end

    dragCompleted = function(e)
        local item = e.target
        --		print('dragCompleted',item.index)
        transition.to(item, { time = 100, alpha = 1 })
        transition.to(item.light, { time = 100, alpha = 0 })
        item.dragtab:setFillColor(0.78, 0.78, 0.78)
    end

    itemMoved = function(e)
        local item = e.target
    --		print('itemMoved',item.index)
    end

    delete = function(e)
        local item = e.target.parent -- the target is the delete button so the list row object is it's parent
        --		print('delete',item.index,item.listname)
        transition.to(item, {
            time = 350,
            alpha = 0,
            onComplete = function()
                item:removeSelf()
                if (item.listname == "F") then
                    totalheight = totalheight - item.itemHeight
                    fListItemCount = fListItemCount - 1
                end
            end
        })
        return true
    end

    -- creates a row using a definition from the rows table above
    newRow = function(text, row)
        local group = display.newGroup()

        -- the shadow around the row, only visible when the row is dragged
        local light = display.newRect(group, 0, -10, 640, row.itemheight + 20)
        light.x = W * 0.5
        light.y = light.height * 0.5
        light:setFillColor(0.19, 0.19, 0.19)
        light.alpha = 0

        group.light = light

        -- the black outline of the row
        local border = display.newRect(group, 0, 0, 640, row.itemheight)
        border:setFillColor(0.19, 0.19, 0.19)
        border.x = W * 0.5
        border.y = border.height * 0.5
        -- the fill of the row
        local back = display.newRect(group, 0, 1, 640, row.itemheight - 1)
        back:setFillColor(row.colour[1], row.colour[2], row.colour[3])
        group.back = back
        back.x = W * 0.5
        back.y = back.height * 0.5

        local textObj = display.newText(group, text, 0, 0, native.systemFont, row.fontsize)
        textObj:setFillColor(0, 0, 0)
        textObj.x = W * 0.5
        textObj.y = row.itemheight * 0.5
        group.textObj = textObj

        -- only add a drag tab if not locked
        local dragtab = nil
        if (not row.isLocked) then
            dragtab = display.newRoundedRect(group, 0, 0, 34, 34, 5)
            dragtab:setFillColor(0.78, 0.78, 0.78)
            dragtab.x = _W - dragtab.width
            dragtab.y = dragtab.height
            if (row.isEdit) then dragtab.alpha = 1 else dragtab.alpha = 0 end
            group.dragtab = dragtab
        end

        -- only add a delete button if the row is not locked
        local deltab = nil
        if (not row.isLocked) then
            deltab = display.newCircle(group, 15, row.itemheight / 2, 10)
            deltab:setFillColor(1, 0, 0)
            if (row.isEdit) then deltab.alpha = 1 else deltab.alpha = 0 end
            deltab:addEventListener("tap", delete)
            deltab.y = deltab.height
            group.deltab = deltab
        end

        return group, dragtab, deltab
    end

    -- iterate through the list of rows and create each one
    local y, name, groupindex = 0, "", 0
    for i = 1, #rows do
        local group, dragtab, deltab = newRow("Row (" .. i .. ")", rows[i])
        rowGrp:insert(group)

        group.x, group.y = 0, y
        y = y + rows[i].itemheight

        if (rows[i].listname ~= name) then groupindex = 1 end

        local head = nil
        if (rows[i].isLocked) then
            head = newRow("Row (" .. i .. ")", rows[i])
            headerGrp:insert(head)
            head.x, head.y = group.x, group.y
        end

        local item = newOrderedItem{
            group = group,
            listname = rows[i].listname,
            index = groupindex,
            itemWidth = 640,
            itemHeight = rows[i].itemheight,
            scrollView = scrollView,
            dragTab = dragtab,
            delTab = deltab,
            isLocked = rows[i].isLocked,
            dragStarted = dragStarted,
            dragCompleted = dragCompleted,
            itemMoved = itemMoved,
            header = head
        }

        name = rows[i].listname
        groupindex = groupindex + 1
    end
end

scene:addEventListener("createScene")

return scene
