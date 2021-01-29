-- Local
concommand.Add( "breakprops_client_localcvars_active", function( ply, command, args )
    RunConsoleCommand( "breakprops_localcvars_active", args[ 1 ] );
end );
concommand.Add( "breakprops_client_change_playerspawn_prop_local", function( ply, command, args )
    RunConsoleCommand( "breakprops_change_playerspawn_prop_local", args[ 1 ] );
end );

if ( not file.Exists( "replace_prop_to_breakable_data.dat", "DATA" ) ) then
    file.Write( "replace_prop_to_breakable_data.dat", "true" );
end;

net.Receive( "cl.replace_prop_to_breakable.warning_menu_open", function()
    local isResetOpenMenu = net.ReadBool();
    local duplicatorType = net.ReadString();

    if ( isResetOpenMenu ) then
        file.Write( "replace_prop_to_breakable_data.dat", "true" );
        return;
    end;

    local file_read = tobool( file.Read( "replace_prop_to_breakable_data.dat", "DATA" ) );

    if ( not file_read ) then return; end;

    local MainMenu = vgui.Create( "DFrame" );
    MainMenu:SetPos( ScrW()/2 - 400/2, ScrH()/2 - 200/2 );
    MainMenu:SetSize( 400, 200 );
    MainMenu:SetTitle( "Replacing props - confirmation menu" );
    MainMenu:SetDraggable( true );
    MainMenu:MakePopup();
    MainMenu.OnClose = function()
        net.Start( "sv.replace_prop_to_breakable.clear" );
        net.SendToServer();
    end;

    local MainMenu_Label = vgui.Create( "DLabel", MainMenu );
    MainMenu_Label:SetPos( 80, 20 );
    MainMenu_Label:SetSize( 300, 100 );
    MainMenu_Label:SetText( "Do you want to replace the props with destructible?\n" ..
        "Attention! Constraints may be destroyed.\nThis function has not yet been finalized.\nUse it at your own risk." );

    local ButtonYes = vgui.Create( "DButton", MainMenu );
    ButtonYes:SetText( "Yes - replace" );
    ButtonYes:SetPos( 30, 120 );
    ButtonYes:SetSize( 155, 30 );
    ButtonYes.DoClick = function()
        net.Start( "sv.replace_prop_to_breakable." .. duplicatorType );
        net.SendToServer();
        MainMenu:Close();
    end;

    local ButtonNo = vgui.Create( "DButton", MainMenu );
    ButtonNo:SetText( "No - not replace" );
    ButtonNo:SetPos( 215, 120 );
    ButtonNo:SetSize( 155, 30 );
    ButtonNo.DoClick = function()
        net.Start( "sv.replace_prop_to_breakable.clear" );
        net.SendToServer();
        MainMenu:Close();
    end;

    local DoNotShow = vgui.Create( "DCheckBox", MainMenu );
    DoNotShow:SetPos( 30, 170 );
    DoNotShow:SetValue( 0 );
    DoNotShow.OnChange = function( self )
        local value = self:GetChecked();
        file.Write( "replace_prop_to_breakable_data.dat", tostring( not value ) );
    end;

    local DoNotShow_Label = vgui.Create( "DLabel", MainMenu );
    DoNotShow_Label:SetPos( 60, 162 );
    DoNotShow_Label:SetSize( 300, 30 );
    DoNotShow_Label:SetText( "Do not show this panel ( Return - !rs_rpb )" );
end );