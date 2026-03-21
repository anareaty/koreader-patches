# KOReader patches

Thes repository contains some patches for Koreader I made for myself or collected from the internet.

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
 

### 2-both-buttons-go-forward.lua

Adds an option to make both forward and backward buttons to go forward in every orientation. Tested on Kobo Libra Colour. You need to set up the gesture action to enable this option. Can be toggled on and off.



