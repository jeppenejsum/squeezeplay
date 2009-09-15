
--[[
=head1 NAME

applets.QVGAlandscapeSkin.QVGAlandscapeSkinApplet - The skin for the Squeezebox Controller

=head1 DESCRIPTION

This applet implements the skin for the Squeezebox Controller

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>.

=cut
--]]


-- stuff we use
local ipairs, pairs, setmetatable, type, package, tostring = ipairs, pairs, setmetatable, type, package, tostring

local oo                     = require("loop.simple")

local Applet                 = require("jive.Applet")
local Audio                  = require("jive.ui.Audio")
local Font                   = require("jive.ui.Font")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Tile                   = require("jive.ui.Tile")
local Window                 = require("jive.ui.Window")
local System                 = require("jive.System")

local table                  = require("jive.utils.table")
local debug                  = require("jive.utils.debug")
local autotable              = require("jive.utils.autotable")

local log                    = require("jive.utils.log").logger("applet.QVGAlandscapeSkin")

local QVGAbaseSkinApplet     = require("applets.QVGAbaseSkin.QVGAbaseSkinApplet")

local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

local WH_FILL                = jive.ui.WH_FILL

local jiveMain               = jiveMain
local appletManager          = appletManager


module(..., Framework.constants)
oo.class(_M, QVGAbaseSkinApplet)


function init(self)
	self.images = {}
end


function param(self)
	return {
		THUMB_SIZE = 41,
		POPUP_THUMB_SIZE = 120,
		NOWPLAYING_MENU = true,
		nowPlayingBrowseArtworkSize = "300x143",
		nowPlayingSSArtworkSize     = 186,
		nowPlayingLargeArtworkSize  = 240,
		nowPlayingTitleStatusLabel  = "artist",
        }
end

-- skin
-- The meta arranges for this to be called to skin Jive.
function skin(self, s, reload, useDefaultSize)
	

	local screenWidth, screenHeight = Framework:getScreenSize()
	local imgpath = 'applets/QVGAlandscapeSkin/images/'
	local baseImgpath = 'applets/QVGAbaseSkin/images/'

	if useDefaultSize or screenWidth < 320 or screenHeight < 240 then
                screenWidth = 320
                screenHeight = 240
        end

        Framework:setVideoMode(screenWidth, screenHeight, 16, jiveMain:isFullscreen())

	--init lastInputType so selected item style is not shown on skin load
	Framework.mostRecentInputType = "scroll"

	-- almost all styles come directly from QVGAbaseSkinApplet
	QVGAbaseSkinApplet.skin(self, s, reload, useDefaultSize)

	-- c is for constants
	local c = s.CONSTANTS

	-- styles specific to the landscape QVGA skin
	s.img.scrollBackground =
                Tile:loadVTiles({
                                        imgpath .. "Scroll_Bar/scrollbar_bkgrd_t.png",
                                        imgpath .. "Scroll_Bar/scrollbar_bkgrd.png",
                                        imgpath .. "Scroll_Bar/scrollbar_bkgrd_b.png",
                                })

	s.img.scrollBar =
                Tile:loadVTiles({
                                        imgpath .. "Scroll_Bar/scrollbar_body_t.png",
                                        imgpath .. "Scroll_Bar/scrollbar_body.png",
                                        imgpath .. "Scroll_Bar/scrollbar_body_b.png",
                               })

        s.scrollbar = {
                w          = 20,
		h          = c.LANDSCAPE_LINE_ITEM_HEIGHT * 4 - 8,
                border     = { 0, 4, 0, 0},  -- bug in jive_menu, makes it so bottom and right values are ignored
                horizontal = 0,
                bgImg      = s.img.scrollBackground,
                img        = s.img.scrollBar,
                layer      = LAYER_CONTENT_ON_STAGE,
        }

	s.img.progressBackground = Tile:loadImage(imgpath .. "Alerts/alert_progress_bar_bkgrd.png")
	s.img.progressBar = Tile:loadHTiles({
                nil,
                imgpath .. "Alerts/alert_progress_bar_body.png",
        })

	s.track_list.menu.scrollbar = _uses(s.scrollbar, {
		h = 41 * 4 - 8,
	})
	-- software update window
	s.update_popup = _uses(s.popup)

	s.update_popup.text = {
                w = WH_FILL,
                h = (c.POPUP_TEXT_SIZE_1 + 8 ) * 2,
                position = LAYOUT_NORTH,
                border = { 0, 14, 0, 0 },
                padding = { 12, 0, 12, 0 },
                align = "center",
                font = _font(c.POPUP_TEXT_SIZE_1),
                lineHeight = c.POPUP_TEXT_SIZE_1 + 8,
                fg = c.TEXT_COLOR,
                sh = c.TEXT_SH_COLOR,
        }

        s.update_popup.subtext = {
                w = WH_FILL,
                -- note this is a hack as the height and padding push
                -- the content out of the widget bounding box.
                h = 30,
                padding = { 0, 0, 0, 36 },
                font = _boldfont(c.UPDATE_SUBTEXT_SIZE),
                fg = c.TEXT_COLOR,
                sh = TEXT_SH_COLOR,
                align = "bottom",
                position = LAYOUT_SOUTH,
        }
	s.update_popup.progress = {
                border = { 12, 0, 12, 12 },
                --padding = { 0, 0, 0, 24 },
                position = LAYOUT_SOUTH,
                horizontal = 1,
                bgImg = s.img.progressBackground,
                img = s.img.progressBar,
        }


	local NP_ARTISTALBUM_FONT_SIZE = 18
	local NP_TRACK_FONT_SIZE = 21

	-- Artwork
	local ARTWORK_SIZE    = self:param().nowPlayingBrowseArtworkSize
	local noArtSize       = tostring(ARTWORK_SIZE)

	local controlHeight   = 38
	local controlWidth    = 45
	local volumeBarWidth  = 150
	local buttonPadding   = 0
	local NP_TITLE_HEIGHT = 31
	local NP_TRACKINFO_RIGHT_PADDING = 40

	local _tracklayout = {
		position = LAYOUT_NORTH,
		w = WH_FILL,
		align = "left",
		lineHeight = NP_TRACK_FONT_SIZE,
		fg = { 0xe7, 0xe7, 0xe7 },
	}

	s.nowplaying = _uses(s.window, {
		title = {
			h = 60,
			text = {
				hidden = 1,
			},
		},
		-- Song metadata
		nptitle = {
			order = { 'nptrack', 'xofy' },
			position   = _tracklayout.position,
			nptrack =  {
				padding    = { 10, 10, 2, 0 },
				w          = WH_FILL,
				align      = _tracklayout.align,
				lineHeight = _tracklayout.lineHeight,
				fg         = _tracklayout.fg,
				font       = _boldfont(NP_TRACK_FONT_SIZE), 
			},
			xofy = {
				padding    = { 0, 10, 10, 0 },
				position   = _tracklayout.position,
				w          = 50,
				align      = 'right',
				fg         = _tracklayout.fg,
				font       = _font(14), 
			},
			xofySmall = {
				padding    = { 0, 10, 10, 0 },
				position   = _tracklayout.position,
				w          = 50,
				align      = 'right',
				fg         = _tracklayout.fg,
				font       = _font(10), 
			},
		},
		npartistalbum  = {
			position   = _tracklayout.position,
			w          = _tracklayout.w,
			align      = _tracklayout.align,
			lineHeight = _tracklayout.lineHeight,
			fg         = { 0xb3, 0xb3, 0xb3 },
			padding    = { 10, NP_TRACK_FONT_SIZE + 14, 10, 0 },
			font       = _font(NP_ARTISTALBUM_FONT_SIZE),
		},
		npalbum = { hidden = 1},
		npartist = { hidden = 1},
	
		-- cover art
		npartwork = {
			position = LAYOUT_WEST,
			w = WH_FILL,
			align = "center",
			artwork = {
				w = WH_FILL,
				align = "center",
				padding = { 0, 66, 0, 0 },
				img = false,
			},
		},
	
		--transport controls
		npcontrols = { hidden = 1 },
	
		-- Progress bar
		npprogress = {
			position = LAYOUT_NORTH,
			padding = { 0, 0, 0, 0 },
			border = { 0, 59, 0, 0 },
			w = WH_FILL,
			order = { "slider" },
		},
	
		-- special style for when there shouldn't be a progress bar (e.g., internet radio streams)
		npprogressNB = {
			hidden = 1,
		},
	
	})

	-- sliders
	-- FIXME: I'd much rather describe slider style within the s.nowplaying window table above, otherwise describing alternative window styles for NP will be problematic
	s.npprogressB = {
		w = screenWidth,
		align = 'center',
                horizontal = 1,
                bgImg = s.img.songProgressBackground,
                img = s.img.songProgressBar,
		h = 15,
		padding = { 0, 0, 0, 15 },
	}

	s.npvolumeB = { hidden = 1 }
	s.nowplayingSS = _uses(s.nowplaying)

end


function free(self)
	local desktop = not System:isHardware()
	if desktop then
		log:warn("reload parent")

		package.loaded["applets.QVGAbaseSkin.QVGAbaseSkinApplet"] = nil
		QVGAbaseSkinApplet     = require("applets.QVGAbaseSkin.QVGAbaseSkinApplet")
	end
        return true
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
