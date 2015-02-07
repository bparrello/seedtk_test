// Jump to a new section in an ERDB documentation page.
function ShowNewBlock(statusThing, objectName) {
    // Push the current block onto the history list.
    statusThing.Push(statusThing.blockNow);
    // Display the new block.
    ShowBlock(statusThing, objectName);
}

// Jump to a new section and clear the history list.
function ShowBlockReset(statusThing, objectName) {
    // Clear the history list.
    statusThing.ClearHistory();
    // Display the new block.
    ShowBlock(statusThing, objectName);
}

// Display a specific section in an ERDB documentation page.
function ShowBlock(statusThing, objectName) {
    // Remember that we're displaying the specified page.
    statusThing.blockNow = objectName;
    // Display the page.
    statusThing.Display(objectName);
    // Update the select box.
    var selectBox = document.getElementById(statusThing.selectBox);
    selectBox.value = objectName;
}

// Display the previous section in an ERDB documentation page.
function ShowPrevious(statusThing) {
    var objectName = statusThing.Pop();
    if (objectName != "") ShowBlock(statusThing, objectName);
}

// DOCUMENTATION STATUS OBJECT

// Create an ERDB documentation page status object.
function ErdbStatusThing(selectBoxID, blockList) {
    // Save the list of block IDs.
    this.blockList = blockList.split(" ");
    // Save the select box ID.
    this.selectBox = selectBoxID;
    // Start with an empty history list.
    this.blockHistory = new Array();
    // Denote there's no current page.
    this.blockNow = "";
}

// Clear the history in a status object.
ErdbStatusThing.prototype.ClearHistory = function() {
    this.blockHistory.length = 0;
}

// Push a new page onto the history list.
ErdbStatusThing.prototype.Push = function(newBlock) {
    this.blockHistory.push(newBlock);
}

// Pop the last page off the history list.
ErdbStatusThing.prototype.Pop = function() {
    var retVal = "";
    if (this.blockHistory.length > 0) {
        retVal = this.blockHistory.pop();
    }
    return retVal;
}

// Hide all the blocks but the specified one.
ErdbStatusThing.prototype.Display = function(blockName) {
    for (var i in this.blockList) {
        var myBlockName = this.blockList[i];
        var myBlock = document.getElementById(myBlockName);
        if (myBlockName == blockName) {
            myBlock.style.display = "block";
        } else {
            myBlock.style.display = "none";
        }
    }
}

// OTHER METHODS

// Use the specified form to put the specified page in the form's target window.
// The name and value passed in will be stored in the hidden input field with
// an ID equal to the formID followed by "_hidden".
function ErdbMiniFormJump(formID, pageURL, parmName, parmValue, tabID, tabIndex) {
    // Select the documentation tab.
    tab_view_select(tabID, tabIndex);
    // Get the form and fill in the target URL.
    var myForm = document.getElementById(formID);
    myForm.action = pageURL;
    // Update the variable parm.
    var myHidden = document.getElementById(formID + "_hidden");
    myHidden.name = parmName;
    myHidden.value = parmValue;
    // Submit the form.
    myForm.submit();
}

// Use the specified field to do a SEED viewer search in a new window.
function SeedViewerJump(fieldID) {
    // Get the field value.
    var myValue = document.getElementById(fieldID).value;
    // Compute a URL from it.
    var myURL = "seedviewer.cgi?page=SearchResult;action=check_search;pattern=" +
        escape(myValue);
    // Open it in a new window.
    window.open(myURL, "sandboxWindow");
}

// This method creates the code for a subroutine based on the data typed
// into the Method Generator form.
function GenerateModule(formID) {
    // Get the method form and the relevant fields.
    var myForm = document.getElementById(formID);
    var mySignature = myForm.elements["Signature"].value;
    var myDescription = myForm.elements["Description"].value;
    var resultField = myForm.elements["Result"];
    // The resulting method code will be stored in the value field.
    resultField.value = "";
    // Insure we have no leading or trailing spaces.
    while (mySignature.slice(-1) == " ") mySignature = mySignature.slice(0, -1);
    while (mySignature.substr(0, 1) == " ") mySignature = mySignature.slice(1);
    // Insure we have a trailing semicolon.
    if (mySignature.slice(-1) != ";") mySignature += ";";
    // We've successfully prettied up the incoming signature. Now we hack off the
    // trailing semicolon so it doesn't complicate our pattern matching.
    var residual = mySignature.slice(0, -1);
    // Function signatures begin with "my" and routine signatures don't,
    // so our first task is to strip off the return value, if one exists.
    var returnValue = "";
    if (mySignature.substr(0, 2) == "my") {
        var pieces = mySignature.match(/my\s+([^=]+)\s+=\s+(.*)/i);
        if (pieces == null) {
            alert("Invalid signature. Probable cause: missing equal sign or spaces.");
        } else {
            returnValue = pieces[1];
            residual = pieces[2];
        }
    }
    // The residual contains the method name, the type (instance or static), and
    // the parameter list. We start with the parameter list.
    var parms = "()";
    var loc = residual.search(/\(.*\)/);
    if (loc >= 0) {
        parms = residual.substr(loc);
        residual = residual.substr(0, loc);
    }
    // The residual now contains the method name and an indication of whether or not it
    // is an instance or static method.
    var callType = "";
    var methodName = residual;
    if ((loc = residual.indexOf('->')) >= 0) {
        callType = "$self";
        methodName = residual.slice(loc + 2);
    } else if ((loc = residual.lastIndexOf('::')) >= 0) {
        methodName = residual.slice(loc + 2);
    }
    // The last thing we need to do is parse the parameter list. First, we strip the parentheses.
    // We use a bit of searching to find the closing paren, which can be at various
    // distances from the end, depending.
    var tail = parms.lastIndexOf(')');
    parms = parms.slice(1, tail);
    // Split the parameters into an array. Note we need special handling to detect
    // the no-parameters case, because the split in that case returns a singleton array
    // instead of an empty array.
    var parmList = new Array(0);
    if (parms != "") {
        parmList = parms.split(/\s*,\s*|\s*=>\s*/);
    }
    // Now we clean the parameter list, removing the backslash notation. The backslash notation
    // is used to clarify the fact that a parameter is a reference to a structure, but it is
    // only valid in the signature itself.
    for (var i = 0; i < parmList.length; i++) {
        if (parmList[i].charAt(0) == "\\") {
            parmList[i] = "$" + parmList[i].slice(2);
        }
    }
    // Now we can start building.
    var lines = new Array();
    // First is the header, the signature, and the description.
    lines.push("=head3 " + methodName, "");
    lines.push("    " + mySignature + "", "");
    // We must now break up the description. We allow a maximum of 72 characters per line, but
    // we keep the user's line breaks.
    var descriptionLines = myDescription.split(/\n/);
    // The splitting is accomplished by splitting each line into words. Lines beginning with
    // spaces are pushed without modification.
    for (var i = 0; i < descriptionLines.length; i++) {
        var thisLine = descriptionLines[i];
        if (thisLine.search(/^\s/) >= 0) {
            lines.push(thisLine);
        } else {
            var myWords = thisLine.split(/\s+/);
            var currentLine = "";
            for (var j = 0; j < myWords.length; j++) {
                var myWord = myWords[j];
                if (currentLine.length + myWord.length > 72) {
                    if (currentLine.length > 0) lines.push(currentLine);
                    currentLine = "";
                }
                // If we have stuff already in the line, we need to insert a space
                // between it and the new word.
                if (currentLine.length > 0) currentLine += " ";
                currentLine += myWord;
            }
            if (currentLine.length > 0) lines.push(currentLine);
        }
    }
    // Put a spacer after the description.
    lines.push("");
    // Do we have parameters? If we do, they get put in an item list.
    if (parmList.length > 0) {
        lines.push("=over 4", "");
        for (var i = 0; i < parmList.length; i++) {
            // Strip off the type indicator.
            var thisParm = parmList[i].slice(1);
            // Generate the item.
            lines.push("=item " + thisParm, "", "##TODO: " + thisParm + " description", "");
        }
        // If there's a return value, add an item for it.
        if (returnValue != "") {
            lines.push("=item RETURN", "", "##TODO: return value description", "");
        }
        // Close the parm list.
        lines.push("=back", "");
    }
    // Cut the documentation and start the method.
    lines.push("=cut", "");
    // Only proceed if DocOnly is NOT set.
    if (! myForm.elements["DocOnly"].checked) {
        lines.push("sub " + methodName + " {");
        // Add the $self thing to the parameter list if this is an instance method.
        if (callType != "") {
            parmList.unshift(callType);
        }
        // If there is a parameter list, generate the code to extract it.
        if (parmList.length > 0) {
            lines.push("    # Get the parameters.",
                       "    my (" + parmList.join(", ") + ") = @_;");
        }
        // If there is a return value, generate the code to declare it.
        if (returnValue != "") {
            // If we have a list return, the return value is used unchanged. Otherwise, we use the
            // variable retVal. Note also that if we have a list return, everything becomes
            // plural.
            var returnType = "";
            if (returnValue.charAt(0) != "(") {
                returnValue = returnValue.charAt(0) + "retVal";
            } else {
                returnType = "s";
            }
            lines.push("    # Declare the return variable" + returnType + ".",
                       "    my " + returnValue + ";");
        }
        // Leave space for the code.
        lines.push("    ##TODO: Code");
        // If there is a return value, generate the code to return it.
        if (returnValue != "") {
            lines.push("    # Return the result" + returnType + ".",
                       "    return " + returnValue + ";");
        }
        // Close the method.
        lines.push("}", "", "", "");
    }
    // Store the code in the result field.
    resultField.value = lines.join("\n");
    // Select all of it.
    resultField.select();
    resultField.focus();
}

// This method clears the Method Generator form.
function ResetForm(formID) {
    // Get the method form and erase the area fields.
    var myForm = document.getElementById(formID);
    myForm.elements["Description"].value = "";
    myForm.elements["Result"].value = "";
    // Get the signature field and select it. This enables the user
    // to choose easily between tweaking the old signature and
    // creating a new one.
    var signatureField = myForm.elements["Signature"];
    signatureField.select();
    signatureField.focus();
}

// This method toggles the display of the element with the
// specified ID. It is fairly primitive, because it presumes
// that when displayed, the element uses the default display
// style.
function TUToggle(elementID) {
    // Find the desired element. If it doesn't exist, we do nothing.
    var actualElement = document.getElementById(elementID);
    if (actualElement !== undefined) {
        if (actualElement.style.display == 'none') {
            actualElement.style.display = '';
        } else {
            actualElement.style.display = 'none';
        }
    }
}

// This method stores the specified value in the specified
// field of the specified form.
function StoreParm(myName, myValue, formID) {
    // Find the form.
    var myForm = document.getElementById(formID);
    // Find the field.
    var myElement = myForm.elements[myName];
    // Store the value.
    myElement.value = myValue;
}

// This runs the test script on the tracing dashboard.
function RunTest(formID) {
    // Get the path URL.
    var myUrl = document.getElementById(formID + "_pathURL").value;
    // Get the base URL.
    var baseUrl = document.getElementById(formID + "_baseURL").value;
    // From the sandbox we compute the full URL.
    var fullUrl = baseUrl + "/" + myUrl;
    // Open it in a new window.
    window.open(fullUrl, "sandboxWindow");
}
