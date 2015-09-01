-- SaveSafariTabsToEvernote saves all names and URI's from Safari to Evernote.
-- This script saves the information in Evernote format including checkboxes 
-- in front of the name and a seperator between the different windows. 
-- The note is saved in the "Bookmarks" notebook.
-- The default settings can be customized by changing the global variables 
-- declared in the beginning of the script. 
-- This script is inspired by and based on a script made by Brett Terpstra:
-- http://brettterpstra.com/2010/03/06/saving-safari-browsing-sessions-to-evernote/
-- [A.W. Alberts|20140203]

property template : "<div style=\"margin-bottom:0.5em\"><en-todo/>%name<br/><small style=\"margin-left:2.5em;\"><a href=\"%url\">%url</a></small><br/></div>"

set prettyDate to do shell script "date '+%A, %B %d, %Y at %H:%M'"
set machineName to computer name of (system info)
set noteTitle to "Bookmarks on " & machineName & " - " & prettyDate
set noteBookName to "Bookmarks"
set everNoteFormat to true
set urlList to ""

on searchAndReplace(toFind, toReplace, theString)
	-- search and replace function for template
	set orgTextItemDelimiters to text item delimiters
	set text item delimiters to toFind
	set textItems to text items of theString
	set text item delimiters to toReplace
	set changedString to textItems as text
	set text item delimiters to orgTextItemDelimiters
	return changedString
end searchAndReplace

on splitUri(theUri)
	set orgTextItemDelimiters to text item delimiters
	set text item delimiters to "://"
	set uriParts to text items of theUri
	set text item delimiters to orgTextItemDelimiters
	return uriParts
end splitUri

on validateUrlProtocol(protocol)
	-- validateUrlProtocol checks if the protocol is valid according to the 
	-- Evernote ENML specifications.
	-- Valid protocols are http://, https:// and file://
	set protocols to {"http", "https", "file"}
	if protocol is in protocols then
		set validProtocol to true
	else
		set validProtocol to false
	end if
	return validProtocol
end validateUrlProtocol

on encodeChar(theChar)
	set the ASCIInumber to (the ASCII number theChar)
	set the hexList to {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
	set firstDigit to item ((ASCIInumber div 16) + 1) of the hexList
	set secondDigit to item ((ASCIInumber mod 16) + 1) of the hexList
	return ("%" & firstDigit & secondDigit) as text
end encodeChar

on urnEncode(theUrn)
	-- See http://en.wikipedia.org/wiki/Percent-encoding for more information 
	-- on reserved and unreserved characters. The '/' character was added to 
	-- the unreserved characters to keep te URI readable
	set the unreservedCharacters to "abcdefghijklmnopqrstuvwxyz0123456789-_.~/"
	set encUrn to ""
	repeat with urnChar in theUrn
		if urnChar is in the unreservedCharacters then
			set encUrn to encUrn & urnChar
		else
			set encUrn to encUrn & encodeChar(urnChar)
		end if
	end repeat
	return encUrn
end urnEncode

on listPosition(listItem, theList)
	repeat with i from 1 to the count of theList
		if ((item i of theList) as text is listItem as text) then return i
	end repeat
	return 0
end listPosition

on replacePredefinedXmlEntitites(theText)
	-- replace the predefined XML entities (&, ", ', <, >) to pass the ENML validation. 
	set xmlText to ""
	set characterList to {"&", "\"", "'", "<", ">"}
	set replacementList to {"&amp;", "&quot;", "&apos;", "&lt;", "&gt;"}
	repeat with theChar in theText
		if (theChar is in characterList) then
			set itemNumber to my listPosition(theChar, characterList)
			set xmlText to xmlText & (item itemNumber of replacementList) as text
		else
			set xmlText to xmlText & theChar
		end if
	end repeat
	return xmlText
end replacePredefinedXmlEntitites

tell application "Safari"
	set windowsList to every window
	repeat with eachWindow in windowsList
		try
			-- WTF code
			if (id of eachWindow) is -1 then
				log "Oops and continue"
				exit repeat
			end if
			repeat with eachTab in (tabs of eachWindow)
				try
					set tabLink to template
					set tabName to name of eachTab
					if everNoteFormat then
						set tabLink to my searchAndReplace("%name", my replacePredefinedXmlEntitites(tabName), tabLink)
						-- separate URL and URN from URI
						set uriParts to my splitUri(URL of eachTab)
						set protocol to get first item of uriParts
						-- validate protocol
						if my validateUrlProtocol(protocol) then
							set urn to get second item of uriParts
							set encUrn to my urnEncode(urn)
							set uri to protocol & "://" & encUrn
							set tabLink to my searchAndReplace("%url", uri, tabLink)
						else
							display dialog "Oops, protocol \"" & protocol & "\" is not supported according to the Evernote ENML specs" buttons {"Continue with html format"}
							set everNoteFormat to false
							set tabLink to my searchAndReplace("%url", URL of eachTab, tabLink)
						end if
					else
						set tabLink to my searchAndReplace("%name", tabName, tabLink)
						set tabLink to my searchAndReplace("%url", URL of eachTab, tabLink)
					end if
					set urlList to urlList & tabLink & return
				on error errMsg number errNum
					display dialog "Something went wrong wile going through the Tab-list: " & errMsg buttons {"Continue"}
				end try
			end repeat
			set urlList to urlList & "<br/><hr/><br/>" & return
		on error errMsg number errNum
			display dialog "Something went wrong wile going through the Window-list: " & errMsg buttons {"Continue"}
		end try
	end repeat
end tell

tell application "Evernote"
	if everNoteFormat then
		set theNote to create note with enml urlList title noteTitle notebook noteBookName
	else
		set theNote to create note with html urlList title noteTitle notebook noteBookName
	end if
end tell
