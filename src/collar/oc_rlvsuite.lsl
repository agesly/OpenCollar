// This file is part of OpenCollar.
// Copyright (c) 2014 - 2017 Wendy Starfall, littlemousy, Sumi Perl,    
// Garvin Twine, Romka Swallowtail et al.   
// Licensed under the GPLv2.  See LICENSE for full details. 

string g_sScriptVersion = "7.3";
//menu setup
string  RESTRICTION_BUTTON          = "Restrictions"; // Name of the submenu
string  RESTRICTIONS_CHAT_COMMAND   = "restrictions";
string  TERMINAL_BUTTON             = "Terminal";   //rlv command terminal button for TextBox
string  TERMINAL_CHAT_COMMAND       = "terminal";
string  OUTFITS_BUTTON              = "Outfits";
string  COLLAR_PARENT_MENU          = "RLV";
string  UPMENU                      = "BACK";
string  BACKMENU                    = "⏎";

integer g_iMenuCommand;
key     g_kMenuClicker;

list    g_lMenuIDs;
integer g_iMenuStride = 3;

//string g_sSettingToken                = "restrictions_";
//string g_sGlobalToken                 = "global_";

//restriction vars
integer g_iSendRestricted;
integer g_iReadRestricted;
integer g_iHearRestricted;
integer g_iTalkRestricted;
integer g_iTouchRestricted;
integer g_iStrayRestricted;
integer g_iRummageRestricted;
integer g_iStandRestricted;
integer g_iDressRestricted;
integer g_iBlurredRestricted;
integer g_iDazedRestricted;

integer g_iSitting;

integer LINK_CMD_DEBUG = 1999;

//outfit vars
integer g_iListener;
integer g_iFolderRLV = 98745923;
integer g_iFolderRLVSearch = 98745925;
integer g_iTimeOut = 30; //timeout on viewer response commands
integer g_iRLVOn = FALSE;
integer g_iRLVaOn = FALSE;
string g_sCurrentPath;
string g_sPathPrefix = ".outfits"; //we look for outfits in here

list g_lAttachments;//2-strided list in form [name, uuid]
key     g_kWearer;
//MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER                   = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER                  = 503;
integer CMD_EVERYONE = 504;
//integer CMD_RLV_RELAY = 507;
integer CMD_SAFEWORD                = 510;
integer CMD_RELAY_SAFEWORD          = 511;
//integer CMD_BLOCKED = 520;

integer NOTIFY                     = 1002;
//integer SAY                        = 1004;
integer REBOOT                     = -1000;
integer LINK_DIALOG = LINK_SET; //                = 3;
integer LINK_RLV = LINK_SET; //                   = 4;
integer LINK_SAVE = LINK_SET; //                  = 5;
integer LINK_UPDATE                = -10;
integer LM_SETTING_SAVE            = 2000;
integer LM_SETTING_REQUEST         = 2001;
integer LM_SETTING_RESPONSE        = 2002;
integer LM_SETTING_DELETE          = 2003;
integer LM_SETTING_EMPTY           = 2004;
//integer LM_SETTING_REQUEST_NOCACHE = 2005;

// messages for creating OC menu structure
integer MENUNAME_REQUEST           = 3000;
integer MENUNAME_RESPONSE          = 3001;
//integer MENUNAME_REMOVE            = 3003;

// messages for RLV commands
integer RLV_CMD                    = 6000;
//integer RLV_REFRESH                = 6001; // RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR                  = 6002; // RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_OFF                    = 6100;
integer RLV_ON                     = 6101;
integer RLVA_VERSION               = 6004;
// messages to the dialog helper
integer DIALOG                     = -9000;
integer DIALOG_RESPONSE            = -9001;
integer DIALOG_TIMEOUT             = -9002;
integer SENSORDIALOG               = -9003;
integer g_iAuth;

key g_kLastForcedSeat;
string g_sLastForcedSeat;
string g_sTerminalText = "\n[RLV Command Terminal]\n\nType one command per line without \"@\" sign.";

/*
integer g_iProfiled=1;
Debug(string sStr) {
    //if you delete the first // from the preceeding and following  lines,
    //  profiling is off, debug is off, and the compiler will remind you to
    //  remove the debug calls from the code, we're back to production mode
    if (!g_iProfiled){
        g_iProfiled=1;
        llScriptProfiler(1);
    }
    llOwnerSay(llGetScriptName() + "(min free:"+(string)(llGetMemoryLimit()-llGetSPMaxMemory())+")["+(string)llGetFreeMemory()+"] :\n" + sStr);
}
*/

Dialog(key kRCPT, string sPrompt, list lButtons, list lUtilityButtons, integer iPage, integer iAuth, string sMenuID) {
    key kMenuID = llGenerateKey();
    if (sMenuID == "sensor" || sMenuID == "find")
        llMessageLinked(LINK_DIALOG, SENSORDIALOG, (string)kRCPT +"|"+sPrompt+"|0|``"+(string)(SCRIPTED|PASSIVE)+"`20`"+(string)PI+"`"+llDumpList2String(lUtilityButtons,"`")+"|"+llDumpList2String(lButtons,"`")+"|" + (string)iAuth, kMenuID);
    else
        llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lButtons, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, sMenuID], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, sMenuID];
}

integer CheckLastSit(key kSit) {
    vector avPos=llGetPos();
    list lastSeatInfo=llGetObjectDetails(kSit, [OBJECT_POS]);
    vector lastSeatPos=(vector)llList2String(lastSeatInfo,0);
    if (llVecDist(avPos,lastSeatPos)<20) return TRUE;
    else return FALSE;
}

SitMenu(key kID, integer iAuth) {
    integer iSitting=llGetAgentInfo(g_kWearer)&AGENT_SITTING;
    string sButton;
    string sitPrompt = "\nAbility to Stand up is ";
    if (g_iStandRestricted) sitPrompt += "restricted by ";
    else sitPrompt += "un-restricted.\n";
    if (g_iStandRestricted == 500) sitPrompt += "Owner.\n";
    else if (g_iStandRestricted == 501) sitPrompt += "Trusted.\n";
    else if (g_iStandRestricted == 502) sitPrompt += "Group.\n";

    if (g_iStandRestricted) sButton = "☑ strict`";
    else sButton = "☐ strict`";
    if (iSitting) sButton+="[Get up]`BACK";
    else {
        if (CheckLastSit(g_kLastForcedSeat)==TRUE) {
            sButton+="[Sit back]`BACK";
            sitPrompt="\nLast forced to sit on "+g_sLastForcedSeat+"\n";
        } else sButton+="BACK";
    }
    Dialog(kID, sitPrompt+"\nChoose a seat:\n", [sButton], [], 0, iAuth, "sensor");
}


RestrictionsMenu(key keyID, integer iAuth) {
    string sPrompt = "\n[Restrictions]";
    list lMyButtons;

    if (g_iSendRestricted) lMyButtons += "☐ Send IMs";
    else lMyButtons += "☑ Send IMs";
    if (g_iReadRestricted) lMyButtons += "☐ Read IMs";
    else lMyButtons += "☑ Read IMs";
    if (g_iHearRestricted) lMyButtons += "☐ Hear";
    else lMyButtons += "☑ Hear";
    if (g_iTalkRestricted) lMyButtons += "☐ Talk";
    else lMyButtons += "☑ Talk";
    if (g_iTouchRestricted) lMyButtons += "☐ Touch";
    else lMyButtons += "☑ Touch";
    if (g_iStrayRestricted) lMyButtons += "☐ Stray";
    else lMyButtons += "☑ Stray";
    if (g_iRummageRestricted) lMyButtons += "☐ Rummage";
    else lMyButtons += "☑ Rummage";
    if (g_iDressRestricted) lMyButtons += "☐ Dress";
    else lMyButtons += "☑ Dress";
    lMyButtons += "RESET";
    if (g_iBlurredRestricted) lMyButtons += "Un-Dazzle";
    else lMyButtons += "Dazzle";
    if (g_iDazedRestricted) lMyButtons += "Un-Daze";
    else lMyButtons += "Daze";

    Dialog(keyID, sPrompt, lMyButtons, ["BACK"], 0, iAuth, "restrictions");
}

DoTerminalCommand(string sMessage, key kID) {
    string sCRLF= llUnescapeURL("%0A");
    list lCommands = llParseString2List(sMessage, [sCRLF], []);
    sMessage = llDumpList2String(lCommands, ",");
    
    llMessageLinked(LINK_RLV,RLV_CMD,sMessage,"Terminal");
    llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Your command(s) were sent to %WEARERNAME%'s Viewer:\n" + sMessage, kID);
    llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"secondlife:///app/agent/"+(string)kID+"/about" + " has changed your rlv restrictions.", g_kWearer);
}

OutfitsMenu(key kID, integer iAuth) {
    g_kMenuClicker = kID; //on our listen response, we need to know who to pop a dialog for
    g_iAuth = iAuth;
    g_sCurrentPath = g_sPathPrefix + "/";
    llSetTimerEvent(g_iTimeOut);
    g_iListener = llListen(g_iFolderRLV, "", g_kWearer, "");
    llOwnerSay("@getinv:"+g_sCurrentPath+"="+(string)g_iFolderRLV);
}

FolderMenu(key keyID, integer iAuth,string sFolders) {
    string sPrompt = "\n[Outfits]";
    sPrompt += "\n\nCurrent Path = "+g_sCurrentPath;
    list lMyButtons = llParseString2List(sFolders,[","],[""]);
    lMyButtons = llListSort(lMyButtons, 1, TRUE);
    // and dispay the menu
    list lStaticButtons;
    if (g_sCurrentPath == g_sPathPrefix+"/") //If we're at root, don't bother with BACKMENU
        lStaticButtons = [UPMENU];
    else {
        if (sFolders == "") lStaticButtons = ["WEAR",UPMENU,BACKMENU];
        else lStaticButtons = [UPMENU,BACKMENU];
    }
    Dialog(keyID, sPrompt, lMyButtons, lStaticButtons, 0, iAuth, "folder");
}

WearFolder (string sStr) { //function grabs g_sCurrentPath, and splits out the final directory path, attaching .core directories and passes RLV commands
    string sAttach ="@attachallover:"+sStr+"=force,attachallover:"+g_sPathPrefix+"/.core/=force";
    string sPrePath;
    list lTempSplit = llParseString2List(sStr,["/"],[]);
    lTempSplit = llList2List(lTempSplit,0,llGetListLength(lTempSplit) -2);
    sPrePath = llDumpList2String(lTempSplit,"/");
    if (g_sPathPrefix + "/" != sPrePath)
        sAttach += ",attachallover:"+sPrePath+"/.core/=force";
   // Debug("rlv:"+sOutput);
    llOwnerSay("@remoutfit=force,detach=force");
    llSleep(1.5); // delay for SSA
    llOwnerSay(sAttach);
}

DetachMenu(key kID, integer iAuth)
{
    //remember not to add button for current object
    //str looks like 0110100001111
    //loop through CLOTH_POINTS, look at char of str for each
    //for each 1, add capitalized button
    string sPrompt = "\nSelect an attachment to remove.\n";
    g_lAttachments = [];

    list attachmentKeys = llGetAttachedList(llGetOwner());
    integer n;
    integer iStop = llGetListLength(attachmentKeys);
    
    for (n = 0; n < iStop; n++) {
        key k = llList2Key(attachmentKeys, n);
        if (k != llGetKey()) {
            g_lAttachments += [llKey2Name(k), k];
        }
    }

    list lButtons;
    iStop = llGetListLength(g_lAttachments);
    
    for (n = 0; n < iStop; n+=2) {
        lButtons += [llList2String(g_lAttachments, n)];
    }
    lButtons = llListSort(lButtons, 1, TRUE);
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "detach");
}

doRestrictions(){
    if (g_iSendRestricted)     llMessageLinked(LINK_RLV,RLV_CMD,"sendim=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"sendim=y","Restrict");

    if (g_iReadRestricted)     llMessageLinked(LINK_RLV,RLV_CMD,"recvim=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"recvim=y","Restrict");

    if (g_iHearRestricted)     llMessageLinked(LINK_RLV,RLV_CMD,"recvchat=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"recvchat=y","Restrict");

    if (g_iTalkRestricted)     llMessageLinked(LINK_RLV,RLV_CMD,"sendchat=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"sendchat=y","Restrict");

    if (g_iTouchRestricted)    llMessageLinked(LINK_RLV,RLV_CMD,"touchall=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"touchall=y","Restrict");

    if (g_iStrayRestricted)    llMessageLinked(LINK_RLV,RLV_CMD,"tplm=n,tploc=n,tplure=n,sittp=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"tplm=y,tploc=y,tplure=y,sittp=y","Restrict");

    if (g_iStandRestricted) {
        if (llGetAgentInfo(g_kWearer)&AGENT_SITTING) llMessageLinked(LINK_RLV,RLV_CMD,"unsit=n","Restrict");
    } else llMessageLinked(LINK_RLV,RLV_CMD,"unsit=y","Restrict");

    if (g_iRummageRestricted)  llMessageLinked(LINK_RLV,RLV_CMD,"showinv=n,viewscript=n,viewtexture=n,edit=n,rez=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"showinv=y,viewscript=y,viewtexture=y,edit=y,rez=y","Restrict");

    if (g_iDressRestricted)    llMessageLinked(LINK_RLV,RLV_CMD,"addattach=n,remattach=n,defaultwear=n,addoutfit=n,remoutfit=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"addattach=y,remattach=y,defaultwear=y,addoutfit=y,remoutfit=y","Restrict");

    if (g_iBlurredRestricted)  llMessageLinked(LINK_RLV,RLV_CMD,"setdebug_renderresolutiondivisor:16=force","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"setdebug_renderresolutiondivisor:1=force","Restrict");

    if (g_iDazedRestricted)    llMessageLinked(LINK_RLV,RLV_CMD,"shownames=n,showhovertextworld=n,showloc=n,showworldmap=n,showminimap=n","Restrict");
    else llMessageLinked(LINK_RLV,RLV_CMD,"shownames=y,showhovertextworld=y,showloc=y,showworldmap=y,showminimap=y","Restrict");
}

releaseRestrictions() {
    g_iSendRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_send","");
    g_iReadRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_read","");
    g_iHearRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_hear","");
    g_iTalkRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_talk","");
    g_iStrayRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_touch","");
    g_iTouchRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_stray","");
    g_iRummageRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_stand","");
    g_iStandRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_rummage","");
    g_iDressRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_dress","");
    g_iBlurredRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_blurred","");
    g_iDazedRestricted=FALSE;
    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_dazed","");

    doRestrictions();
}
string bool2string(integer iTest){
    if(iTest)return "true";
    else return "false";
}
integer g_iTerminalAccess=12; // This is the bitset indicating what levels can access, or cannot access, the terminal. Default is only owner, trusted and wearer, see the link message section for a explanation of the bitset.
UserCommand(integer iNum, string sStr, key kID, integer bFromMenu) {
    string sLowerStr=llToLower(sStr);
    //Debug(sStr);
    //outfits command handling
    if (sLowerStr == "outfits" || sLowerStr == "menu outfits") {
        if (g_iRLVaOn) OutfitsMenu(kID, iNum);
        else {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"\n\nSorry! This feature can't work on RLV and will require a RLVa enabled viewer. The regular \"# Folders\" feature is a good alternative.\n" ,kID);
            llMessageLinked(LINK_RLV, iNum, "menu " + COLLAR_PARENT_MENU, kID);
        }
        return;
    } else if (llSubStringIndex(sStr,"wear ") == 0) {
        if (!g_iRLVaOn) {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"\n\nSorry! This feature can't work on RLV and will require a RLVa enabled viewer. The regular \"# Folders\" feature is a good alternative.\n" ,kID);
            if (bFromMenu) llMessageLinked(LINK_RLV, iNum, "menu " + COLLAR_PARENT_MENU, kID);
            return;
        } else if (g_iDressRestricted)
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Oops! Outfits can't be worn while the ability to dress is restricted.",kID);
        else {
            sLowerStr = llDeleteSubString(sStr,0,llStringLength("wear ")-1);
            if (sLowerStr) { //we have a folder to try find...
                llSetTimerEvent(g_iTimeOut);
                g_iListener = llListen(g_iFolderRLVSearch, "", g_kWearer, "");
                g_kMenuClicker = kID;
                if (g_iRLVaOn) {
                    llOwnerSay("@findfolders:"+sLowerStr+"="+(string)g_iFolderRLVSearch);
                }
                else {
                    llOwnerSay("@findfolder:"+sLowerStr+"="+(string)g_iFolderRLVSearch);
                }
            }
        }
        if (bFromMenu) OutfitsMenu(kID, iNum);
        return;
    }
    //restrictions command handling
    
    
    
    integer iNoAccess=FALSE;
    if (sStr == TERMINAL_CHAT_COMMAND || sStr == "menu " + TERMINAL_BUTTON) {
        
        /// g_iTerminalAccess as of v7.2 will define the access rights for the terminal.
        // A flag is set if denied.
        if((g_iTerminalAccess&1) && iNum ==CMD_WEARER) { 
            iNoAccess=TRUE;
            return;
        }else if((g_iTerminalAccess&2) && iNum == CMD_TRUSTED){
            iNoAccess=TRUE;
            return;
        }else if((g_iTerminalAccess&4)&& iNum == CMD_EVERYONE){
            iNoAccess=TRUE;
            return;
        }else if((g_iTerminalAccess&8)&&iNum == CMD_GROUP){
            iNoAccess=TRUE;
            return;
        }
        
        // CMD_OWNER is never denied terminal. CMD_OWNER is the access level of the owner level as well as the unowned or selfowned wearer.
        
        if (sStr == TERMINAL_CHAT_COMMAND) g_iMenuCommand = FALSE;
        else g_iMenuCommand = TRUE;
        
        string sAppendSettings = "Wearer blocked: "+bool2string((g_iTerminalAccess&1))+"\nTrusted blocked: "+bool2string((g_iTerminalAccess&2))+"\nPublic blocked: "+bool2string((g_iTerminalAccess&4))+"\nGroup blocked: "+bool2string((g_iTerminalAccess&8))+"\n\nFor help configuring, type 'help' without the quotes!\nTo exit the terminal, simply type 'back'";
        
        Dialog(kID, g_sTerminalText+"\n"+sAppendSettings, [], [], 0, iNum, "terminal");
        return;
    } else if(sStr == RESTRICTIONS_CHAT_COMMAND || sStr == "menu "+RESTRICTION_BUTTON){
        RestrictionsMenu(kID, iNum);
        return;
    }
    
    
    if (sLowerStr == "restrictions back") {
        llMessageLinked(LINK_RLV, iNum, "menu " + COLLAR_PARENT_MENU, kID);
        return;
    } else if (sLowerStr == "restrictions reset" || sLowerStr == "allow all"){
        if (iNum == CMD_OWNER) releaseRestrictions();
        else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☐ send ims" || sLowerStr == "allow sendim"){
        if (iNum <= g_iSendRestricted || !g_iSendRestricted) {
            g_iSendRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_send","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Send IMs is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ send ims" || sLowerStr == "forbid sendim"){
        if (iNum <= g_iSendRestricted || !g_iSendRestricted) {
            g_iSendRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_send="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Send IMs is restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☐ read ims" || sLowerStr == "allow readim"){
        if (iNum <= g_iReadRestricted || !g_iReadRestricted) {
            g_iReadRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_read","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Read IMs is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ read ims" || sLowerStr == "forbid readim"){
        if (iNum <= g_iReadRestricted || !g_iReadRestricted) {
            g_iReadRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_read="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Read IMs is restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☐ hear" || sLowerStr == "allow hear"){
        if (iNum <= g_iHearRestricted || !g_iHearRestricted) {
            g_iHearRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_hear","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Hear is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ hear" || sLowerStr == "forbid hear"){
        if (iNum <= g_iHearRestricted || !g_iHearRestricted) {
            g_iHearRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_hear="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Hear is restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☐ touch" || sLowerStr == "allow touch"){
        if (iNum <= g_iTouchRestricted || !g_iTouchRestricted) {
            g_iTouchRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_touch","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Touch is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ touch" || sLowerStr == "forbid touch"){
        if (iNum <= g_iTouchRestricted || !g_iTouchRestricted) {
            g_iTouchRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_touch="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Touch restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☐ stray" || sLowerStr == "allow stray"){
        if (iNum <= g_iStrayRestricted || !g_iStrayRestricted) {
            g_iStrayRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_stray","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Stray is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ stray" || sLowerStr == "forbid stray"){
        if (iNum <= g_iStrayRestricted || !g_iStrayRestricted) {
            g_iStrayRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_stray="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Stray is restricted",kID);
        } else iNoAccess=TRUE;
        //2015-04-10 added Otto
    } else if (sLowerStr == "restrictions ☐ stand" || sLowerStr == "allow stand"){
        if (iNum <= g_iStandRestricted || !g_iStandRestricted) {
            g_iStandRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_stand","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Stand up is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ stand" || sLowerStr == "forbid stand"){
        if (iNum <= g_iStandRestricted || !g_iStandRestricted) {
            g_iStandRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_stand="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Stand up is restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☐ talk" || sLowerStr == "allow talk"){
        if (iNum <= g_iTalkRestricted || !g_iTalkRestricted) {
            g_iTalkRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_talk","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Talk is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ talk" || sLowerStr == "forbid talk"){
        if (iNum <= g_iTalkRestricted || !g_iTalkRestricted) {
            g_iTalkRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_talk="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Talk is restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☐ rummage" || sLowerStr == "allow rummage"){
        if (iNum <= g_iRummageRestricted || !g_iRummageRestricted) {
            g_iRummageRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_rummage","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Rummage is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ rummage" || sLowerStr == "forbid rummage"){
        if (iNum <= g_iRummageRestricted || !g_iRummageRestricted) {
            g_iRummageRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_rummage="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Rummage is restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☐ dress" || sLowerStr == "allow dress"){
        if (iNum <= g_iDressRestricted || !g_iDressRestricted) {
            g_iDressRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_dress","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Dress is un-restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions ☑ dress" || sLowerStr == "forbid dress"){
        if (iNum <= g_iDressRestricted || !g_iDressRestricted) {
            g_iDressRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_dress="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Ability to Dress is restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions un-dazzle" || sLowerStr == "undazzle"){
        if (iNum <= g_iBlurredRestricted || !g_iBlurredRestricted) {
            g_iBlurredRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_blurred","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Vision is clear",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions dazzle" || sLowerStr == "dazzle"){
        if (iNum <= g_iBlurredRestricted || !g_iBlurredRestricted) {
            g_iBlurredRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_blurred="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Vision is restricted",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions un-daze" || sLowerStr == "undaze"){
        if (iNum <= g_iDazedRestricted || !g_iDazedRestricted) {
            g_iDazedRestricted=FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"restrictions_dazed","");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Clarity is restored",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "restrictions daze" || sLowerStr == "daze"){
        if (iNum <= g_iDazedRestricted || !g_iDazedRestricted) {
            g_iDazedRestricted=iNum;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"restrictions_dazed="+(string)iNum,"");
            doRestrictions();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1Confusion is imposed",kID);
        } else iNoAccess=TRUE;
    } else if (sLowerStr == "stand" || sLowerStr == "standnow"){
        if (iNum <= g_iStandRestricted || !g_iStandRestricted) {
            llMessageLinked(LINK_RLV,RLV_CMD,"unsit=y,unsit=force","Restrict");
            g_iSitting = FALSE;
            //UserCommand(iNum, "allow stand", kID, FALSE);
            //llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"\n\n%WEARERNAME% is allowed to stand once again.\n",kID);
            llSleep(0.5);
        } else iNoAccess=TRUE;
        if (bFromMenu) SitMenu(kID, iNum);
        return;
    } else if (sLowerStr == "menu force sit" || sLowerStr == "sit" || sLowerStr == "sitnow"){
        if(iNum!=CMD_WEARER)
            SitMenu(kID, iNum);
        else iNoAccess=TRUE;
       /* if (iNum <= g_iStandRestricted || !g_iStandRestricted) SitMenu(kID, iNum);
        else {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0%NOACCESS%",kID);
            if (bFromMenu) llMessageLinked(LINK_RLV, iNum, "menu "+COLLAR_PARENT_MENU, kID);
        } */
        return;
    } else if (sLowerStr == "sit back") {
        if (iNum <= g_iStandRestricted || !g_iStandRestricted) {
            if (CheckLastSit(g_kLastForcedSeat)==FALSE) return;
            llMessageLinked(LINK_RLV,RLV_CMD,"unsit=y,unsit=force","Restrict");
            llSleep(0.5);
            llMessageLinked(LINK_RLV,RLV_CMD,"sit:"+(string)g_kLastForcedSeat+"=force","Restrict");
            if (g_iStandRestricted) llMessageLinked(LINK_RLV,RLV_CMD,"unsit=n","Restrict");
            g_iSitting = TRUE;
            llSleep(0.5);
        } else iNoAccess=TRUE;
        if (bFromMenu) SitMenu(kID, iNum);
        return;
    } else if (llSubStringIndex(sLowerStr,"sit ") == 0) {
        if (iNum <= g_iStandRestricted || !g_iStandRestricted) {
            sLowerStr = llDeleteSubString(sStr,0,llStringLength("sit ")-1);
            if ((key)sLowerStr) {
                llMessageLinked(LINK_RLV,RLV_CMD,"unsit=y,unsit=force","Restrict");
                llSleep(0.5);
                g_kLastForcedSeat=(key)sLowerStr;
                g_sLastForcedSeat=llKey2Name(g_kLastForcedSeat);
                llMessageLinked(LINK_RLV,RLV_CMD,"sit:"+sLowerStr+"=force","Restrict");
                if (g_iStandRestricted) llMessageLinked(LINK_RLV,RLV_CMD,"unsit=n","Restrict");
                g_iSitting = TRUE;
                llSleep(0.5);
            } else {
                Dialog(kID, "", [""], [sLowerStr,"1"], 0, iNum, "find");
                return;
            }
        } else iNoAccess=TRUE;
        if (bFromMenu) SitMenu(kID, iNum);
        return;
    } else if (sLowerStr == "clear") {
        releaseRestrictions();
        return;
    } else if (!llSubStringIndex(sLowerStr, "hudtpto:") && (iNum == CMD_OWNER || iNum == CMD_TRUSTED)) {
        if (g_iRLVOn) llMessageLinked(LINK_RLV,RLV_CMD,llGetSubString(sLowerStr,3,-1),"");
    } else if (sLowerStr == "menu detach" || sLowerStr == "detach") {
        DetachMenu(kID, iNum); 
    }
    
    if(iNoAccess)llMessageLinked(LINK_DIALOG,NOTIFY, "0%NOACCESS%", kID);
    if (bFromMenu) RestrictionsMenu(kID,iNum);
}

default {

    state_entry() {
        g_kWearer = llGetOwner();
        //Debug("Starting");
        string R="restrictions";
        list tokens = [R+"send",R+"read", R+"hear", R+"talk",R+"touch",R+"stray", R+"stand",R+"rummage", R+"blurred", R+"dazed", "terminal_accessbitset"];
        integer i=0;
        integer end=llGetListLength(tokens);
        for(i=0;i<end;i++){
            llMessageLinked(LINK_SAVE, LM_SETTING_REQUEST, llList2String(tokens,i),"");
        }
        tokens=[];end=0;i=0;
    }

    on_rez(integer iParam) {
        if (llGetOwner()!=g_kWearer) llResetScript();
        g_iRLVOn = FALSE;
        g_iRLVaOn = FALSE;
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == MENUNAME_REQUEST && sStr == COLLAR_PARENT_MENU) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, COLLAR_PARENT_MENU + "|" + RESTRICTION_BUTTON, "");
            llMessageLinked(iSender, MENUNAME_RESPONSE, COLLAR_PARENT_MENU + "|Force Sit", "");
            llMessageLinked(iSender, MENUNAME_RESPONSE, COLLAR_PARENT_MENU + "|" + TERMINAL_BUTTON, "");
            llMessageLinked(iSender, MENUNAME_RESPONSE, COLLAR_PARENT_MENU + "|" + OUTFITS_BUTTON, "");
            llMessageLinked(iSender, MENUNAME_RESPONSE, COLLAR_PARENT_MENU + "|Detach", "");
        } else if (iNum == LM_SETTING_EMPTY) {
            if (sStr=="restrictions_send")         g_iSendRestricted=FALSE;
            else if (sStr=="restrictions_read")    g_iReadRestricted=FALSE;
            else if (sStr=="restrictions_hear")    g_iHearRestricted=FALSE;
            else if (sStr=="restrictions_talk")    g_iTalkRestricted=FALSE;
            else if (sStr=="restrictions_touch")   g_iTouchRestricted=FALSE;
            else if (sStr=="restrictions_stray")   g_iStrayRestricted=FALSE;
            else if (sStr=="restrictions_stand")   g_iStandRestricted=FALSE;
            else if (sStr=="restrictions_rummage") g_iRummageRestricted=FALSE;
            else if (sStr=="restrictions_blurred") g_iBlurredRestricted=FALSE;
            else if (sStr=="restrictions_dazed")   g_iDazedRestricted=FALSE;
            else if(sStr == "terminal_accessbitset") g_iTerminalAccess=0;
        } else if (iNum == LM_SETTING_RESPONSE || iNum == LM_SETTING_SAVE) { // we should set these values on save or load.
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (~llSubStringIndex(sToken,"restrictions_")){
                if (sToken=="restrictions_send")          g_iSendRestricted=(integer)sValue;
                else if (sToken=="restrictions_read")     g_iReadRestricted=(integer)sValue;
                else if (sToken=="restrictions_hear")     g_iHearRestricted=(integer)sValue;
                else if (sToken=="restrictions_talk")     g_iTalkRestricted=(integer)sValue;
                else if (sToken=="restrictions_touch")    g_iTouchRestricted=(integer)sValue;
                else if (sToken=="restrictions_stray")    g_iStrayRestricted=(integer)sValue;
                else if (sToken=="restrictions_stand")    g_iStandRestricted=(integer)sValue;
                else if (sToken=="restrictions_rummage")  g_iRummageRestricted=(integer)sValue;
                else if (sToken=="restrictions_blurred")  g_iBlurredRestricted=(integer)sValue;
                else if (sToken=="restrictions_dazed")    g_iDazedRestricted=(integer)sValue;
            } else if(~llSubStringIndex(sToken, "terminal_")){
                if(sToken == "terminal_accessbitset") g_iTerminalAccess=(integer)sValue;
            }
        }
        else if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sStr, kID,FALSE);
        else if (iNum == RLV_ON) {
            g_iRLVOn = TRUE;
            doRestrictions();
            if (g_iSitting && g_iStandRestricted) {
                if (CheckLastSit(g_kLastForcedSeat)==TRUE) {
                    llMessageLinked(LINK_RLV,RLV_CMD,"sit:"+(string)g_kLastForcedSeat+"=force","Restrict");
                    if (g_iStandRestricted) llMessageLinked(LINK_RLV,RLV_CMD,"unsit=n","Restrict");
                } else llMessageLinked(LINK_RLV,RLV_CMD,"unsit=y","Restrict");
            }
        } else if (iNum == RLV_OFF) {
            g_iRLVOn = FALSE;
            releaseRestrictions();
        } else if (iNum == RLV_CLEAR) releaseRestrictions();
        else if (iNum == RLVA_VERSION) g_iRLVaOn = TRUE;
        else if (iNum == CMD_SAFEWORD || iNum == CMD_RELAY_SAFEWORD) releaseRestrictions();
        else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                list lMenuParams = llParseStringKeepNulls(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                //integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                //Debug("Sending restrictions "+sMessage);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (sMenu == "restrictions") UserCommand(iAuth, "restrictions "+sMessage,kAv,TRUE);
                else if (sMenu == "sensor") {
                    if (sMessage=="BACK") {
                        llMessageLinked(LINK_RLV, iAuth, "menu " + COLLAR_PARENT_MENU, kAv);
                        return;
                    }
                    else if (sMessage == "[Sit back]") UserCommand(iAuth, "sit back", kAv, FALSE);
                    else if (sMessage == "[Get up]") UserCommand(iAuth, "stand", kAv, FALSE);
                    else if (sMessage == "☑ strict") UserCommand(iAuth, "allow stand",kAv, FALSE);
                    else if (sMessage == "☐ strict") UserCommand(iAuth, "forbid stand",kAv, FALSE);
                    else UserCommand(iAuth, "sit "+sMessage, kAv, FALSE);
                    UserCommand(iAuth, "menu force sit", kAv, TRUE);
                } else if (sMenu == "find") UserCommand(iAuth, "sit "+sMessage, kAv, FALSE);
                else if (sMenu == "terminal") {
                    
                    if(iAuth == CMD_OWNER ){
                        list tmp = llParseString2List(llToLower(sMessage), [" "],[]);
                        integer iTerminate=FALSE;
                        if(llList2String(tmp,0)=="allow"){
                            integer iAddAccess;
                            iTerminate=TRUE;
                            if(llList2String(tmp,1) == "wearer"  && (g_iTerminalAccess&1))iAddAccess=1;
                            if(llList2String(tmp,1) == "trusted" && (g_iTerminalAccess&2))iAddAccess=2;
                            if(llList2String(tmp,1) == "public" && (g_iTerminalAccess&4))iAddAccess=4;
                            if(llList2String(tmp,1) == "group" && (g_iTerminalAccess&8))iAddAccess=8;
                            
                            g_iTerminalAccess=(g_iTerminalAccess-iAddAccess);
                        } else if(llList2String(tmp,0)=="deny"){
                            integer iRemAccess;
                            iTerminate=TRUE;
                            if(llList2String(tmp,1) == "wearer" && !(g_iTerminalAccess&1))iRemAccess=1;
                            if(llList2String(tmp,1) == "trusted" && !(g_iTerminalAccess&2))iRemAccess=2;
                            if(llList2String(tmp,1) == "public" && !(g_iTerminalAccess&4))iRemAccess=4;
                            if(llList2String(tmp,1) == "group" && !(g_iTerminalAccess&8))iRemAccess=8;
                            
                            g_iTerminalAccess=(g_iTerminalAccess+iRemAccess);
                        }else if(llList2String(tmp,0)=="help"){
                            iTerminate=TRUE;
                            llInstantMessage(kAv, "The following config options are available for the terminal. Please note that only CMD_OWNER can execute the configuration commands.\n{allow/deny} {wearer,public,group,trusted}\nAn example command would look like this: deny public\nYou can also type 'back' into the terminal to exit to the RLV menu.");
                        } else if(llList2String(tmp,0)=="back"){
                            llMessageLinked(LINK_RLV,iAuth,"menu "+COLLAR_PARENT_MENU,kAv);
                            return;
                        }
                        if(iTerminate){
                            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "terminal_accessbitset="+(string)g_iTerminalAccess,"");
                            llMessageLinked(LINK_SET, iAuth, "menu Terminal", kAv); 
                            return; // this is not a RLV command. We're safe to exit here.
                        }// if it was NOT a config command, then process as a RLV command.
                    }
                    
                    
                    
                    if (llStringLength(sMessage) > 4) DoTerminalCommand(sMessage, kAv);
                    llMessageLinked(LINK_SET, iAuth, "menu Terminal", kAv);
                } else if (sMenu == "folder" || sMenu == "multimatch") {
                    g_kMenuClicker = kAv;
                    if (sMessage == UPMENU)
                        llMessageLinked(LINK_RLV, iAuth, "menu "+COLLAR_PARENT_MENU, kAv);
                    else if (sMessage == BACKMENU) {
                        list lTempSplit = llParseString2List(g_sCurrentPath,["/"],[]);
                        lTempSplit = llList2List(lTempSplit,0,llGetListLength(lTempSplit) -2);
                        g_sCurrentPath = llDumpList2String(lTempSplit,"/") + "/";
                        llSetTimerEvent(g_iTimeOut);
                        g_iAuth = iAuth;
                        g_iListener = llListen(g_iFolderRLV, "", g_kWearer, "");
                        llOwnerSay("@getinv:"+g_sCurrentPath+"="+(string)g_iFolderRLV);
                    } else if (sMessage == "WEAR") WearFolder(g_sCurrentPath);
                    else if (sMessage != "") {
                        g_sCurrentPath += sMessage + "/";
                        if (sMenu == "multimatch") g_sCurrentPath = sMessage + "/";
                        llSetTimerEvent(g_iTimeOut);
                        g_iAuth = iAuth;
                        g_iListener = llListen(g_iFolderRLV, "", llGetOwner(), "");
                        llOwnerSay("@getinv:"+g_sCurrentPath+"="+(string)g_iFolderRLV);
                    }
                } else if (sMenu == "detach") {
                    if (sMessage == UPMENU) {
                        llMessageLinked(LINK_RLV, iAuth, "menu "+COLLAR_PARENT_MENU, kAv);
                    } else {              
                        integer idx = llListFindList(g_lAttachments, [sMessage]);
                        if (~idx) {
                            string uuid = llList2String(g_lAttachments, idx + 1);
                            //send the RLV command to remove it.
                            if (g_iRLVOn) {
                                llOwnerSay("@remattach:" + uuid + "=force");
                            }
                            //sleep for a sec to let things detach
                            llSleep(0.5);
                        }
                        //Return menu
                        DetachMenu(kAv, iAuth);
                    }
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
         else if(iNum == LINK_CMD_DEBUG){
            integer onlyver=0;
            if(sStr == "ver")onlyver=1;
            llInstantMessage(kID, llGetScriptName() +" SCRIPT VERSION: "+g_sScriptVersion);
            if(onlyver)return; // basically this command was: <prefix> versions
            // The rest of this command can be access by <prefix> debug
            llInstantMessage(kID, llGetScriptName()+" RESTRICTIONS: "+llDumpList2String([g_iSendRestricted, g_iReadRestricted, g_iHearRestricted, g_iTalkRestricted, g_iTouchRestricted, g_iStrayRestricted, g_iRummageRestricted, g_iStandRestricted, g_iDressRestricted, g_iBlurredRestricted, g_iDazedRestricted], ", "));
            llInstantMessage(kID, llGetScriptName()+" TERMINAL ACCESS: "+(string)g_iTerminalAccess);
        }
    }

    listen(integer iChan, string sName, key kID, string sMsg) {
        //llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
        //Debug((string)iChan+"|"+sName+"|"+(string)kID+"|"+sMsg);
        if (iChan == g_iFolderRLV) { //We got some folders to process
            FolderMenu(g_kMenuClicker,g_iAuth,sMsg); //we use g_kMenuClicker to respond to the person who asked for the menu
            g_iAuth = CMD_EVERYONE;
        }
        else if (iChan == g_iFolderRLVSearch) {
            if (sMsg == "") {
                llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"That outfit couldn't be found in #RLV/"+g_sPathPrefix,kID);
            } else { // we got a match
                if (llSubStringIndex(sMsg,",") < 0) {
                    g_sCurrentPath = sMsg;
                    WearFolder(g_sCurrentPath);
                    //llOwnerSay("@attachallover:"+g_sPathPrefix+"/.core/=force");
                    llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Loading outfit #RLV/"+sMsg,kID);
                } else {
                    string sPrompt = "\nPick one!";
                    list lFolderMatches = llParseString2List(sMsg,[","],[]);
                    Dialog(g_kMenuClicker, sPrompt, lFolderMatches, [UPMENU], 0, g_iAuth, "multimatch");
                    g_iAuth = CMD_EVERYONE;
                }
            }
        }
    }

    timer() {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
    }
}
