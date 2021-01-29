AddCSLuaFile();

util.AddNetworkString( "cl.replace_prop_to_breakable.warning_menu_open" );
util.AddNetworkString( "sv.replace_prop_to_breakable.duplicator" );
util.AddNetworkString( "sv.replace_prop_to_breakable.adv2duplicator" );
util.AddNetworkString( "sv.replace_prop_to_breakable.clear" );

-- Global
CreateConVar("breakprops_active", 1, FCVAR_ARCHIVE, "Turns on or off the destroyed props. (1:ON, 0:OFF)");
CreateConVar("breakprops_change_map_doors", 1, FCVAR_ARCHIVE, "Replaces all doors on the map with destructible ones. (1:ON, 0:OFF)");
CreateConVar("breakprops_change_map_props", 1, FCVAR_ARCHIVE, "Replaces all props on the map with destructible ones. (1:ON, 0:OFF)");
CreateConVar("breakprops_change_playerspawn_prop", 1, FCVAR_ARCHIVE, "It makes the prop disruptible if it is spawned by the player. (1:ON, 0:OFF)");

-- Local
concommand.Add( "breakprops_localcvars_active", function( ply, command, args )
    local uid64 = "single_player";
    
    if ( not game.SinglePlayer() ) then
        uid64 = tostring( ply:SteamID64() );
    end;

    if ( args[ 1 ] == nil ) then
        local arg = file.Read( "rpb_data/" .. uid64 .. "/breakprops_localcvars_active.dat", "DATA" );
        local description = "Activation or deactivation of client parameters.";

        ply:SendLua( [[ MsgN( "breakprops_localcvars_active = ]] .. arg .. [[" ) ]] );
        ply:SendLua( [[ MsgN( "Description: ]] .. description .. [[" ) ]] );
    end;

    if ( args[ 1 ] == '1' ) then
        file.Write( "rpb_data/" .. uid64 .. "/breakprops_localcvars_active.dat", "1" );
    elseif ( args[ 1 ] == '0' ) then
        file.Write( "rpb_data/" .. uid64 .. "/breakprops_localcvars_active.dat", "0" );
    end;
end );

concommand.Add( "breakprops_change_playerspawn_prop_local", function( ply, command, args )
    local uid64 = "single_player";
    
    if ( not game.SinglePlayer() ) then
        uid64 = tostring( ply:SteamID64() );
    end;

    if ( args[ 1 ] == nil ) then
        local arg = file.Read( "rpb_data/" .. uid64 .. "/breakprops_change_playerspawn_prop.dat", "DATA" );
        local description = "Enables or disables the creation of player destructible objects, if the variable on the server is negative.";

        ply:SendLua( [[ MsgN( "breakprops_change_playerspawn_prop = ]] .. arg .. [[" ) ]] );
        ply:SendLua( [[ MsgN( "Description:" ) ]] );
        ply:SendLua( [[ MsgN( "Description: ]] .. description .. [[" ) ]] );
    end;

    if ( file.Read( "rpb_data/" .. uid64 .. "/breakprops_localcvars_active.dat", "DATA" ) == "0" ) then
        return; 
    end;
    
    if ( file.Read( "rpb_data/" .. uid64 .. "/breakprops_change_playerspawn_prop.dat", "DATA" ) == "0" ) then
        return; 
    end;
    
    if ( args[ 1 ] == '1' ) then
        file.Write( "rpb_data/" .. uid64 .. "/breakprops_change_playerspawn_prop.dat", "1" );
    elseif ( args[ 1 ] == '0' ) then
        file.Write( "rpb_data/" .. uid64 .. "/breakprops_change_playerspawn_prop.dat", "0" );
    end;
end );

local CreateConstraintFromEnts;
local hookIndex = "ReplacePropToBreakProp_";
local doors_save = {};

local function IsDoorLocked( ent )
    return ent:GetSaveTable().m_bLocked;
end;

local function getReplaceModel( model )
    local new_model = nil;

    if ( string.sub( model, 8, 16 ) == "props_c17" ) then
        new_model = "models/nseven/" .. string.sub( model, 18 );
    elseif ( string.sub( model, 8, 17 ) == "props_junk" ) then
        new_model = "models/nseven/" .. string.sub( model, 19 );
    elseif ( string.sub( model, 8, 16 ) == "props_lab" ) then
        new_model = "models/nseven/" .. string.sub( model, 18 );
    elseif ( string.sub( model, 8, 22 ) == "props_wasteland" ) then
        new_model = "models/nseven/" .. string.sub( model, 24 );
    elseif ( string.sub( model, 8, 22 ) == "props_interiors" ) then
        new_model = "models/nseven/" .. string.sub( model, 24 );
    elseif ( string.sub( model, 8, 20 ) == "props_combine" ) then
        new_model = "models/nseven/" .. string.sub( model, 22 );
    elseif ( string.sub( model, 8, 21 ) == "props_vehicles" ) then
        new_model = "models/nseven/" .. string.sub( model, 23 );
    elseif ( string.sub( model, 8, 25 ) == "props_trainstation" ) then
        new_model = "models/nseven/" .. string.sub( model, 27 );
    elseif ( string.sub( model, 8, 21 ) == "props_borealis" ) then
        new_model = "models/nseven/" .. string.sub( model, 23 );
    elseif ( string.sub( model, 8, 27 ) == "props_phx/construct/" ) then
        new_model = "models/nseven/" .. string.sub( model, 28, string.len( model ) );
    end;
    
    return new_model;
end;

local function isBreakableModel( model )
    if ( string.find( model, "nseven" ) ) then
        return true;
    end;
    return false;
end;

local function propReplace( ply, model, ent, class, delay_remove_time, isDuplicator )
    class = class or "prop_physics";
    delay_remove_time = delay_remove_time or 0;
    isDuplicator = isDuplicator or false;

    local new_model = getReplaceModel( model );
    if ( new_model ~= nil and util.IsValidModel( new_model ) ) then
        local class = class;
        local pos = ent:GetPos();
        local ang = ent:GetAngles();
        local skin = ent:GetSkin();
        local bodygroups = ent:GetBodyGroups();
        local color = ent:GetColor();
        local phys = ent:GetPhysicsObject();
        local drag = phys:IsDragEnabled();
        local gravity = phys:IsGravityEnabled();
        local collision = phys:IsCollisionEnabled();
        local motion = phys:IsMotionEnabled();
        local collisionGroup = ent:GetCollisionGroup();
        local velocity = ent:GetVelocity();
        local doorLock = nil;

        if ( class == "prop_door_rotating" ) then
            doorLock = IsDoorLocked( ent );
        end

        ent:SetCollisionGroup( COLLISION_GROUP_WORLD );

        local nEnt = ents.Create(class);
        nEnt:SetModel( new_model );
        nEnt:SetPos( pos );
        nEnt:SetAngles( ang );
        nEnt:SetSkin( skin );
        nEnt:SetBodyGroups( bodygroups );
        nEnt:SetColor( color );
        nEnt.Owner = ply or game.GetWorld();
        if ( DPP ~= nil ) then
            DPP.SetOwner( nEnt, nEnt.Owner );
        elseif ( FPP ~= nil ) then
            nEnt.FPPOwner = nEnt.Owner;
        end;
        nEnt:SetCollisionGroup( collisionGroup );
        if ( class == "prop_door_rotating" ) then
            if ( doorLock ) then
                nEnt:Fire( "Lock" );
            else
                nEnt:Fire( "Unlock" );
            end;
        end;
        nEnt.IsBreakableNsevenProp = true;
        nEnt:Spawn();
        
        if ( delay_remove_time ~= nil and delay_remove_time ~= 0 ) then
            ent:SetNoDraw( true );
            phys:EnableMotion( false );
            phys:EnableCollisions( false );
            phys:EnableDrag( false );
            phys:EnableGravity( false );
        end;

        nEnt:Activate();
        phys = nEnt:GetPhysicsObject();
        if ( IsValid( phys ) ) then
            phys:EnableDrag( drag );
            phys:EnableGravity( gravity );
            phys:EnableCollisions( collision );
            phys:EnableMotion( motion );
            phys:SetVelocity( velocity );
        end;

        if (ply ~= NULL) then
            timer.Simple( 0.01, function()
                if ( not isDuplicator ) then
                    undo.ReplaceEntity( ent, nEnt );
                    cleanup.ReplaceEntity( ent, nEnt );
                end;

                if ( delay_remove_time == nil or delay_remove_time == 0 ) then
                    ent:Remove();
                else
                    timer.Simple( delay_remove_time, function()
                        if ( IsValid( ent ) ) then
                            ent:Remove();
                        end;
                    end );
                end;
            end );
        else
            timer.Simple( 0.01, function()
                if ( not isDuplicator ) then
                    cleanup.ReplaceEntity( ent, nEnt );
                end;

                if ( delay_remove_time == nil or delay_remove_time == 0 ) then
                    ent:Remove();
                else
                    timer.Simple( delay_remove_time, function()
                        if ( IsValid( ent ) ) then
                            ent:Remove();
                        end;
                    end );
                end;
            end );
        end;
        return nEnt;
    elseif ( string.sub( model, 1, 13 ) == "models/nseven" ) then
        ent.Owner = ply or game.GetWorld();
        ent.IsBreakableNsevenProp = true;
        return ent;
    end;
    return NULL;
end;

local function PropReplaceInMap()
    if ( GetConVar("breakprops_active"):GetInt() <= 0 ) then return; end;
    table.Empty( doors_save );
    do
        if ( GetConVar("breakprops_change_map_doors"):GetInt() == 1 ) then
            local doors = ents.FindByClass( "prop_door_rotating" );
            local j = #doors;
            if (j ~= 0) then
                for i = 1, j do
                    local ent = doors[i];
                    if ( ent:GetClass() == "prop_door_rotating" ) then
                        local new_model = getReplaceModel( ent:GetModel() );
                        if ( new_model ~= nil ) then
                            local info = {
                                entity = ent,
                                model = new_model,
                                skin = ent:GetSkin(),
                                pos = ent:GetPos(),
                                ang = ent:GetAngles(),
                                spawn = false,
                            };
                            local index = table.insert( doors_save, info );
                            ent.doorIndex = index;
                        end;
                    end;
                end;
            end;
        end;
    end;
    do
        local props = ents.FindByClass( "prop_physics" );
        local j = #props;
        if (j ~= 0) then
            for i = 1, j do
                local ent = props[i];
                local class = ent:GetClass();

                if ( class == "prop_physics" ) then
                    if ( GetConVar("breakprops_change_map_props"):GetInt() <= 0 ) then return; end;
                    propReplace( NULL, ent:GetModel(), ent, class );
                end;
            end;
        end;
    end;
end;
hook.Add( "InitPostEntity", hookIndex.."InitPostEntity", PropReplaceInMap );
hook.Add( "PostCleanupMap", hookIndex.."PostCleanupMap", PropReplaceInMap );


local isUseDefaultDuplicator = false;
local isUseDefaultDuplicator_Delay = 0;

hook.Add( "CanTool", hookIndex.."CanTool", function( ply, tr, tool )
    if ( tool == "duplicator" ) then
        isUseDefaultDuplicator = true;
        isUseDefaultDuplicator_Delay = CurTime() + 0.2;
    end;
end );

hook.Add( "PlayerInitialSpawn", hookIndex.."PlayerInitialSpawn", function( ply )
    local uid64 = "single_player";
    
    if ( not game.SinglePlayer() ) then
        uid64 = tostring( ply:SteamID64() );
    end;

    ply.IsDuplicatorUse = false;

    if ( not file.IsDir( "rpb_data", "DATA" ) ) then
        file.CreateDir( "rpb_data" );
    end;

    if ( not file.IsDir( "rpb_data/" .. uid64, "DATA" ) ) then
        file.CreateDir( "rpb_data/" .. uid64 );
    end;

    if ( not file.Exists(  "rpb_data/" .. uid64 .. "/breakprops_change_playerspawn_prop.dat", "DATA" ) ) then
        file.Write( "rpb_data/" .. uid64 .. "/breakprops_change_playerspawn_prop.dat", "1" );
    end;

    if ( not file.Exists(  "rpb_data/" .. uid64 .. "/breakprops_localcvars_active.dat", "DATA" ) ) then
        file.Write( "rpb_data/" .. uid64 .. "/breakprops_localcvars_active.dat", "0" );
    end;
end );

net.Receive( "sv.replace_prop_to_breakable.clear", function( len, ply )
    table.Empty( ply.DuplicatorEntities );
    table.Empty( ply.Adv2DuplicatorEntities );
end );

net.Receive( "sv.replace_prop_to_breakable.duplicator", function( len, ply )
    CreateConstraintFromEnts( ply, ply.DuplicatorEntities );
    timer.Simple( 0.2, function()
        table.Empty( ply.DuplicatorEntities );
    end );
end );

net.Receive( "sv.replace_prop_to_breakable.adv2duplicator", function( len, ply )
    CreateConstraintFromEnts( ply, ply.Adv2DuplicatorEntities );
    timer.Simple( 0.2, function()
        table.Empty( ply.Adv2DuplicatorEntities );
    end );
end );


hook.Add( "PlayerSpawnedProp", hookIndex.."PlayerSpawnedProp", function( ply, model, ent ) 
    if ( GetConVar("breakprops_active"):GetInt() <= 0 ) then return; end;
    if ( GetConVar("breakprops_change_playerspawn_prop"):GetInt() <= 0 ) then
        local falue = true;

        local uid64 = "single_player";
    
        if ( not game.SinglePlayer() ) then
            uid64 = tostring( ply:SteamID64() );
        end;
        
        if ( file.Read( "rpb_data/" .. uid64 .. "/breakprops_localcvars_active.dat", "DATA" ) == "1" ) then
            if ( file.Read( "rpb_data/" .. uid64 .. "/breakprops_change_playerspawn_prop.dat", "DATA" ) == "1" ) then
                falue = false;
            end;
        end;

        if ( falue ) then return; end;
    end;

    if ( isBreakableModel( model ) ) then
        ent.IsBreakableNsevenProp = true;
    end;

    ply.Adv2DuplicatorEntities = ply.Adv2DuplicatorEntities or {};
    ply.DuplicatorEntities = ply.DuplicatorEntities or {};
    --[[ Заметка: как то нужно сделать эти ёбаные соединения ]]--
    -- ply.Adv2DuplicatorEntitiesConstruct = ply.Adv2DuplicatorEntitiesConstruct or {};
    --[[ Заметка: как то нужно сделать эти ёбаные соединения ]]--
    if ( ply.AdvDupe2 ~= nil and ply.AdvDupe2.Pasting  ) then 
        do
            ent.Owner = ply;
            table.insert( ply.Adv2DuplicatorEntities, ent );
            local check = {};
            check.func = function()
                if ( not ply.AdvDupe2.Pasting ) then
                    if ( #ply.Adv2DuplicatorEntities ~= 0 ) then
                        -- CreateConstraintFromEnts( ply, ply.Adv2DuplicatorEntities );
                        -- timer.Simple( 0.1, function()
                        --     if ( not ply.AdvDupe2.Pasting ) then
                        --         table.Empty( ply.Adv2DuplicatorEntities );
                        --     end;
                        -- end );

                        -- Хочу какать

                        for _, select_ent in pairs( ply.Adv2DuplicatorEntities ) do
                            if ( select_ent.isBreakableChecked ) then return; end;

                            if ( IsValid( select_ent ) and not isBreakableModel( select_ent:GetModel() ) ) then

                                for _, select_ent2 in pairs( ply.Adv2DuplicatorEntities ) do
                                    select_ent2.isBreakableChecked = true;
                                end;

                                net.Start( "cl.replace_prop_to_breakable.warning_menu_open" );
                                    net.WriteBool( false );
                                    net.WriteString( "adv2duplicator" );
                                net.Send( ply );

                                return;
                            end;
                        end;

                         table.Empty( ply.Adv2DuplicatorEntities );
                    end;
                else
                    timer.Simple( 0.1, check.func );
                end;
            end;
            check.func();
        end;
    elseif ( isUseDefaultDuplicator ) then 
        do
            ent.Owner = ply;
            table.insert( ply.DuplicatorEntities, ent );
            local check = {};
            check.func = function()
                if ( isUseDefaultDuplicator and isUseDefaultDuplicator_Delay < CurTime() ) then
                    isUseDefaultDuplicator = false;
                    if ( #ply.DuplicatorEntities ~= 0 ) then
                        local isEmptyTable = true;

                        for _, select_ent in pairs( ply.DuplicatorEntities ) do
                            if ( select_ent.isBreakableChecked ) then return; end;

                            if ( IsValid( select_ent ) and not isBreakableModel( select_ent:GetModel() ) ) then

                                for _, select_ent2 in pairs( ply.Adv2DuplicatorEntities ) do
                                    select_ent2.isBreakableChecked = true;
                                end;

                                net.Start( "cl.replace_prop_to_breakable.warning_menu_open" );
                                    net.WriteBool( false );
                                    net.WriteString( "duplicator" );
                                net.Send( ply );

                                isEmptyTable = false;
                                
                                return;
                            end;
                        end;

                        table.Empty( ply.DuplicatorEntities );
                    end;
                else
                    timer.Simple( 0.1, check.func );
                end;
            end;
            check.func();
        end;
    elseif ( ( ply.AdvDupe2 == nil or not ply.AdvDupe2.Pasting )  ) then 
        propReplace( ply, model, ent, ent:GetClass() );
    end;
end );

hook.Add( "EntityTakeDamage", hookIndex.."Door_EntityTakeDamage", function( ent, dmg )
    if ( GetConVar("breakprops_change_map_doors"):GetInt() == 1 and ent:GetClass() == "prop_door_rotating" ) then

        if ( ent.doorIndex ~= nil and doors_save[ent.doorIndex] ~= nil and not doors_save[ent.doorIndex].spawn and not ent:GetNoDraw() ) then

            ent.propBreakableDoorHp = ent.propBreakableDoorHp or 150;
            ent.propBreakableDoorHp = ent.propBreakableDoorHp - dmg:GetDamage();

            if ( ent.propBreakableDoorHp <= 0 ) then
                ent:SetNotSolid( true );
                ent:SetNoDraw( true );
                
                local door_info = doors_save[ent.doorIndex];
                local dir = dmg:GetDamageForce():GetNormalized();
                local force = dir * math.max( math.sqrt( dmg:GetDamageForce():Length() / 1000 ), 1 ) * 1000;
                local door = ents.Create( "prop_physics" );
                door:SetModel( door_info.model );
                door:SetSkin( door_info.skin );
                door:SetPos( door_info.pos );
                door:SetAngles( door_info.ang );    
                door.DestructDoor = true;
                door:Spawn();
                door:SetVelocity( force );
                door:GetPhysicsObject():ApplyForceOffset( force, dmg:GetDamagePosition() );
                door:SetPhysicsAttacker( dmg:GetAttacker() );
                door:EmitSound( "physics/wood/wood_furniture_break" .. tostring( math.random( 1, 2 ) ) .. ".wav", 110, math.random( 90, 110 ) );

                doors_save[ent.doorIndex].spawn = true;
                ent.propBreakableDoorHp = 150;

                door:TakeDamageInfo( dmg );

                local respawn = {};
                respawn.door = function( door, break_door )
                    if ( IsValid( break_door ) ) then
                        break_door:Remove();
                    end;
                    if ( IsValid( door ) and door.doorIndex ~= nil ) then
                        local obb_mins = LocalToWorld( door:OBBMins(), Angle(), door:GetPos(), door:GetAngles() );
                        local obb_max = LocalToWorld( door:OBBMaxs(), Angle(), door:GetPos(), door:GetAngles() );
                        local objects = ents.FindInBox( obb_mins, obb_max );
                        local notspawn = false;
                        for _, v in pairs ( objects ) do
                            if ( v:IsPlayer() ) then
                                notspawn = true;
                                timer.Simple( 1, function()
                                    respawn.door( door, NULL );
                                end );
                                break;
                            end;
                        end;

                        if ( notspawn ) then return; end;

                        doors_save[door.doorIndex].spawn = false;
                        door:SetNotSolid( false );
                        door:SetNoDraw( false );
                    end;
                end;
                timer.Simple( 60, function()
                    respawn.door( ent, door );
                end );

            end;

        end;

    end;
end );

hook.Add("EntityTakeDamage", hookIndex.."EntityTakeDamage", function( ent, dmg )
    if ( GetConVar("breakprops_active"):GetInt() <= 0 ) then return; end;
    local class = ent:GetClass();
    if ( class == "prop_physics" ) then
        local model = ent:GetModel();
        if ( ent.IsBreakableNsevenProp or ( string.len( model ) > 14 and string.sub( model, 1, 14 ) == "models/nseven/" ) ) then
            local old_prop = ent;
            local owner = old_prop.Owner;
            local getpos = old_prop:GetPos();
            local DestructDoor = old_prop.DestructDoor;
            --[[ Заметка: возможная система поиска пропов ]]--
            -- local obb_mins = LocalToWorld( old_prop:OBBMins(), Angle(), old_prop:GetPos(), old_prop:GetAngles() );
            -- local obb_max = LocalToWorld( old_prop:OBBMaxs(), Angle(), old_prop:GetPos(), old_prop:GetAngles() );
            --[[ Заметка: возможная система поиска пропов ]]--
            local more = false;
            timer.Simple( 0.01, function()
                local objects = ents.FindInSphere( getpos, 10 );
                --[[ Заметка: возможная система поиска пропов ]]--
                -- local objects = ents.FindInBox( obb_mins, obb_max );
                -- for _, v in pairs ( objects ) do
                --     print( v:GetModel() )
                -- end;
                --[[ Заметка: возможная система поиска пропов ]]--
                if ( table.Count( objects ) > 1 ) then
                    more = true;
                    undo.Create( "Prop" );
                    undo.SetPlayer( owner );
                end;
                for _, prop in pairs( objects ) do
                    if ( IsValid( prop ) and prop ~= old_prop and prop:GetClass() == "prop_physics" ) then
                        local new_model = prop:GetModel();
                        if (    string.sub( new_model , 1, 20 ) == "models/nseven/debris" or 
                                string.sub( new_model , 1, 11 ) == "models/gibs" or
                                string.sub( new_model , 1, 13 ) == "models/nseven" 
                        ) then
                            if ( not IsValid( owner ) and DestructDoor ) then
                                prop.DestructDoor = true;
                                timer.Simple( 30, function()
                                    if ( IsValid( prop ) ) then
                                        prop:Remove();
                                    end;
                                end );
                            else
                                prop.Owner = owner;
                                prop.IsBreakableNsevenProp = true;
                                if ( DPP ~= nil ) then
                                    DPP.SetOwner( prop, owner );
                                elseif ( FPP ~= nil ) then
                                    prop.FPPOwner = owner;
                                end;
                                if ( owner ~= NULL and owner:IsPlayer() ) then
                                    if ( more ) then
                                        undo.AddEntity( prop );
                                    elseif ( old_prop == NULL ) then
                                        undo.Create( "Prop" );
                                        undo.SetPlayer( owner );
                                        undo.AddEntity( prop );
                                        undo.Finish();
                                    elseif ( not more ) then
                                        undo.ReplaceEntity( old_prop, prop );
                                        cleanup.ReplaceEntity( old_prop, prop );
                                        old_prop = NULL;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
                if ( more ) then
                    undo.Finish();
                end;
            end );
        end;
    end;
end)

CreateConstraintFromEnts = function( ply, Original_EntList )
    local Old_Ents = {};
    local New_Ents = {};
    local Ents = {};
    local Ents_Keys = {};
    local Constraints = {};
    local Constraints_Keys = {};

    duplicator.GetAllConstrainedEntitiesAndConstraints( Original_EntList[ 1 ], Ents, Constraints );

    for key, _ in pairs( Constraints ) do
        table.insert( Constraints_Keys, key );
    end;

    for key, _ in pairs( Ents ) do
        table.insert( Ents_Keys, key );
    end;

    undo.Create( "Prop" );
    undo.SetPlayer( ply );

    for _, sEnt in pairs( Original_EntList ) do
        if ( IsValid( sEnt ) ) then
            local _getEnt = propReplace( sEnt.Owner, sEnt:GetModel(), sEnt, sEnt:GetClass(), 30, true );

            if ( IsValid( _getEnt ) ) then
                table.insert( Old_Ents, sEnt );
                table.insert( New_Ents, { New = _getEnt, Old = sEnt } );

                undo.AddEntity( _getEnt );
            else
                undo.AddEntity( sEnt );
            end;
        end;
    end;

    undo.Finish();

    local _get_constraint = {};
    for i_constraint = 1, table.Count( Constraints_Keys ) do
        _get_constraint = Constraints[ Constraints_Keys[ i_constraint ] ];
        -- Create NoCollide constraint
        do
            if ( _get_constraint[ 'Type' ] == "NoCollide" ) then
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                local result = constraint.NoCollide( Ent1, Ent2, Bone1, Bone2 );
            end;
        end;
        -- Create Weld constraint
        do
            if ( _get_constraint[ 'Type' ] == "Weld" ) then
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local Forcelimit = _get_constraint[ 'forcelimit' ];
                local NoCollide = _get_constraint[ 'nocollide' ];
                local DeleteonBreak = _get_constraint[ 'deleteonbreak' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Weld( Ent1, Ent2, Bone1, Bone2, Forcelimit, NoCollide, DeleteonBreak );
            end;
        end;
        -- Create Rope constraint
        do
            if ( _get_constraint[ 'Type' ] == "Rope" ) then
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Length = _get_constraint[ 'length' ];
                local Addlength = _get_constraint[ 'addlength' ];
                local Forcelimit = _get_constraint[ 'forcelimit' ];
                local Width = _get_constraint[ 'width' ];
                local Material = _get_constraint[ 'material' ];
                local Rigid = _get_constraint[ 'rigid' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Rope( Ent1, Ent2, Bone1, Bone2, LPos1, LPos2, Length, Addlength, Forcelimit, 
                    Width, Material, Rigid );
            end;
        end;
        -- Create Hydraulic constraint
        do
            if ( _get_constraint[ 'Type' ] == "Hydraulic" ) then
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Length1 = _get_constraint[ 'Length1' ];
                local Length2 = _get_constraint[ 'Length2' ];
                local Key = _get_constraint[ 'key' ];
                local Speed = _get_constraint[ 'speed' ];
                local Width = _get_constraint[ 'width' ];
                local Material = _get_constraint[ 'material' ];
                local Fixed = _get_constraint[ 'fixed' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Hydraulic( ply, Ent1, Ent2, Bone1, Bone2, LPos1, LPos2, Length1, 
                    Length2, Width, Key, Fixed, Speed, material );
            end;
        end;
        -- Create Keepupright constraint
        do
            if ( _get_constraint[ 'Type' ] == "Keepupright" ) then
                local Ent = _get_constraint[ 'ent' ];
                local Ang = _get_constraint[ 'ang' ];
                local Bone = _get_constraint[ 'bone' ];
                local AngularLimit = _get_constraint[ 'angularLimit' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent' ] == value.Old ) then
                        Ent = value.New;
                    end;
                end;

                constraint.Keepupright( Ent, Ang, Bone, AngularLimit );
            end;
        end;
         -- Create Motor constraint
         do
            if ( _get_constraint[ 'Type' ] == "Motor" ) then
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Friction = _get_constraint[ 'friction' ];
                local Torque = _get_constraint[ 'torque' ];
                local Forcetime = _get_constraint[ 'forcetime' ];
                local NoCollide = _get_constraint[ 'nocollide' ];
                local Toggle = _get_constraint[ 'toggle' ];
                local Forcelimit = _get_constraint[ 'forcelimit' ];
                local NumpadkeyFWD = _get_constraint[ 'numpadkey_fwd' ];
                local NumpadkeyBWD = _get_constraint[ 'numpadkey_bwd' ];
                local Direction = _get_constraint[ 'direction' ];
                local LocalAxis = _get_constraint[ 'LocalAxis' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Motor( Ent1, Ent2, Bone1, Bone2, LPos1, LPos2, Friction, Torque, Forcetime, 
                    NoCollide, Toggle, ply, Forcelimit, NumpadkeyFWD, NumpadkeyBWD, Direction, LocalAxis );
            end;
        end;
        -- Create AdvBallsocket constraint
        do
            if ( _get_constraint[ 'Type' ] == "AdvBallsocket" ) then
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Forcelimit = _get_constraint[ 'forcelimit' ];
                local Torquelimit = _get_constraint[ 'torquelimit' ];
                local Xmin = _get_constraint[ 'xmin' ];
                local YMin = _get_constraint[ 'ymin' ];
                local ZMin = _get_constraint[ 'zmin' ];
                local Xmax = _get_constraint[ 'xmax' ];
                local YMax = _get_constraint[ 'ymax' ];
                local ZMax = _get_constraint[ 'zmax' ];
                local XFric = _get_constraint[ 'xfric' ];
                local YFric = _get_constraint[ 'yfric' ];
                local ZFric = _get_constraint[ 'zfric' ];
                local OnlyRotation = _get_constraint[ 'onlyrotation' ];
                local Torquelimit = _get_constraint[ 'torquelimit' ];
                local NoCollide = _get_constraint[ 'nocollide' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.AdvBallsocket( Ent1, Ent2, Bone1, Bone2, LPos1, 
                    LPos2, Forcelimit, Torquelimit, Xmin, YMin, ZMin, 
                    Xmax, YMax, ZMax, XFric, YFric, ZFric, OnlyRotation, NoCollide );
            end;
        end;
        -- Create Axis constraint
        do
            if ( _get_constraint[ 'Type' ] == "Axis" ) then
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Friction = _get_constraint[ 'friction' ];
                local Forcelimit = _get_constraint[ 'forcelimit' ];
                local Torquelimit = _get_constraint[ 'torquelimit' ];
                local LocalAxis = _get_constraint[ 'LocalAxis' ];
                local DontAddTable = _get_constraint[ 'DontAddTable' ];
                local OnlyRotation = _get_constraint[ 'onlyrotation' ];
                local Torquelimit = _get_constraint[ 'torquelimit' ];
                local NoCollide = _get_constraint[ 'nocollide' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Axis( Ent1, Ent2, Bone1, Bone2, LPos1, LPos2, 
                    Forcelimit, Torquelimit, Friction, NoCollide, LocalAxis, DontAddTable );
            end;
        end;
        -- Create Ballsocket constraint
        do
            if ( _get_constraint[ 'Type' ] == "Ballsocket" ) then
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local LocalPos = _get_constraint[ 'LPos' ];
                local Forcelimit = _get_constraint[ 'forcelimit' ];
                local Torquelimit = _get_constraint[ 'torquelimit' ];
                local NoCollide = _get_constraint[ 'nocollide' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Ballsocket( Ent1, Ent2, Bone1, Bone2, LocalPos, Forcelimit, Torquelimit, NoCollide );
            end;
        end;
        -- Create Elastic constraint
        do
            if ( _get_constraint[ 'Type' ] == "Elastic" ) then
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Constant = _get_constraint[ 'constant' ];
                local Damping = _get_constraint[ 'damping' ];
                local Rdamping = _get_constraint[ 'rdamping' ];
                local Material = _get_constraint[ 'material' ];
                local Width = _get_constraint[ 'width' ];
                local Stretchonly = _get_constraint[ 'stretchonly' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Elastic( Ent1, Ent2, Bone1, Bone2, LPos1, LPos2, 
                    Constant, Damping, Rdamping, Material, Width, Stretchonly );
            end;
        end;
        -- Create Muscle constraint
        do
            if ( _get_constraint[ 'Type' ] == "Muscle" ) then
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Length1 = _get_constraint[ 'Length1' ];
                local Length2 = _get_constraint[ 'Length2' ];
                local Key = _get_constraint[ 'key' ];
                local Material = _get_constraint[ 'material' ];
                local Width = _get_constraint[ 'width' ];
                local Fixed = _get_constraint[ 'fixed' ];
                local Period = _get_constraint[ 'period' ];
                local Amplitude = _get_constraint[ 'amplitude' ];
                local Starton = _get_constraint[ 'starton' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Muscle( ply, Ent1, Ent2, Bone1, Bone2, LPos1, LPos2, Length1, Length2, width, 
                    Key, Fixed, Period, Amplitude, Starton, Material );
            end;
        end;
        -- Create Pulley constraint
        do
            if ( _get_constraint[ 'Type' ] == "Pulley" ) then
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent4 = _get_constraint[ 'Ent2' ];
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone4 = _get_constraint[ 'Bone4' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos4 = _get_constraint[ 'LPos4' ];
                local WPos2 = _get_constraint[ 'WPos2' ];
                local WPos3 = _get_constraint[ 'WPos3' ];
                local Forcelimit = _get_constraint[ 'forcelimit' ];
                local Rigid = _get_constraint[ 'rigid' ];
                local Material = _get_constraint[ 'material' ];
                local Width = _get_constraint[ 'width' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent4' ] == value.Old ) then
                        Ent4 = value.New;
                    end;
                end;

                constraint.Pulley( Ent1, Ent4, Bone1, Bone4, LPos1, LPos4, WPos2, WPos3, Forcelimit, Rigid, Width, Material );
            end;
        end;
        -- Create Slider constraint
        do
            if ( _get_constraint[ 'Type' ] == "Slider" ) then
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Material = _get_constraint[ 'material' ];
                local Width = _get_constraint[ 'width' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Slider( Ent1, Ent2, Bone1, Bone2, LPos1, LPos2, Width, Material );
            end;
        end;
         -- Create Winch constraint
         do
            if ( _get_constraint[ 'Type' ] == "Winch" ) then
                local Ent1 = _get_constraint[ 'Ent1' ];
                local Ent2 = _get_constraint[ 'Ent2' ];
                local Bone1 = _get_constraint[ 'Bone1' ];
                local Bone2 = _get_constraint[ 'Bone2' ];
                local LPos1 = _get_constraint[ 'LPos1' ];
                local LPos2 = _get_constraint[ 'LPos2' ];
                local Material = _get_constraint[ 'material' ];
                local Width = _get_constraint[ 'width' ];
                local fwd_bind = _get_constraint[ 'fwd_bind' ];
                local bwd_bind = _get_constraint[ 'bwd_bind' ];
                local fwd_speed = _get_constraint[ 'fwd_speed' ];
                local bwd_speed = _get_constraint[ 'bwd_speed' ];
                local toggle = _get_constraint[ 'toggle' ];

                for key, value in pairs( New_Ents ) do
                    if ( _get_constraint[ 'Ent1' ] == value.Old ) then
                        Ent1 = value.New;
                    end;
                    if ( _get_constraint[ 'Ent2' ] == value.Old ) then
                        Ent2 = value.New;
                    end;
                end;

                constraint.Winch( ply, Ent1, Ent2, Bone1, Bone2, LPos1, LPos2, Width, fwd_bind, 
                    bwd_bind, fwd_speed, bwd_speed, Material, toggle );
            end;
        end;
    end;

    for _, OldEnt in pairs( Old_Ents ) do
        OldEnt:Remove();
    end;

    table.Empty( Old_Ents );
    table.Empty( New_Ents );
    table.Empty( Ents );
    table.Empty( Ents_Keys );
    table.Empty( Constraints );
    table.Empty( Constraints_Keys );
end;

hook.Add("PlayerSay", hookIndex.."PlayerSay", function( ply, text, isTeamChat )
    local getText = string.Replace( text, " ", "" );

    if ( getText == "!rs_rpb" or getText == "/rs_rpb" ) then
        net.Start( "cl.replace_prop_to_breakable.warning_menu_open" );
            net.WriteBool( true );
        net.Send( ply );
    end;
end );