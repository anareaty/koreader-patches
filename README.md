# KOReader patches

Thes repository contains some patches for Koreader I made for myself or collected from the internet.


## My patches

### 2-better-highlights.lua

This patch combines two functions to make expirience of working with highlights better:

1. Sets custom colors. I use different, darker colors for underlines to make them more visible.
2. Changes the highlights menu to be able to select colors immediately and also replaces commands with icons.

![menu](/screenshots/menu.png)

![menu](/screenshots/editmenu.png)

For this menu to work, you need to copy icons from the `better-highlights-icons` folder to `koreader/icons/` folder. 

Long-press to select underline instead of highlights.

I removed some commands I don't use, like Wikipedia.

### 2-collection-actions.lua

Creates actions for every collection, so you can access them directly, without opening collections list. Useful if you have some collections you are using more often then the other.

### 2-remove-book-opening-message.lua

To not show info message when the book opens.  

### 2-rename-items-in quick menu.lua

Provides customisible way to replace text of any commands in quick menus. Edit the patch to set your own replacements.

### 2-replace-menu-swipe.lua

Replaces gestures for top and bottom menu zones to set my own commands. Work in progress. Buggy in landscape mode.
Currently set the same gestures as two-finger swipes. 
Failsafe gesture: hold with two fingers on top menu zone.

### 2-compact-book-menu.lua

Replaces the book menu with a nicer and more useful, and with icons.

### 2-ui-hist-and col-menu.lua

Replaces the menus in history views and collections.

### 2-update-book-data-on-history-or-collection.lua

Updates current book data when history or collections are open, to make sure the progress is shown correctly.

## Patches made by other people

### 2--ui-font-lua
### 2-statusbar-thin-chapter
### 2-thicker-underline

