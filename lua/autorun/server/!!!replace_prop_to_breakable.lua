AddCSLuaFile();
CreateConVar("breakprops_active", 1, FCVAR_ARCHIVE, "Turns on or off the destroyed props. (1:ON, 0:OFF)");
CreateConVar("breakprops_change_map_doors", 1, FCVAR_ARCHIVE, "Replaces all doors on the map with destructible ones. (1:ON, 0:OFF)");
CreateConVar("breakprops_change_map_props", 1, FCVAR_ARCHIVE, "Replaces all props on the map with destructible ones. (1:ON, 0:OFF)");
CreateConVar("breakprops_change_playerspawn_prop", 1, FCVAR_ARCHIVE, "It makes the prop disruptible if it is spawned by the player. (1:ON, 0:OFF)");
CreateConVar("breakprops_off_adv2", 1, FCVAR_ARCHIVE, "The system does not work on objects from the duplicator in order not to break the connection of entities. (1:ON, 0:OFF)");

local hookIndex = "ReplacePropToBreakProp_";
local doors_save = {};

local function IsDoorLocked( ent )
    return ent:GetSaveTable().m_bLocked;
end;

local function propIsBreakable( model )
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
    elseif ( string.sub( model, 8, 21 ) == "props_vehicles" ) then
        new_model = "models/nseven/" .. string.sub( model, 23 );
    elseif ( string.sub( model, 8, 25 ) == "props_trainstation" ) then
        new_model = "models/nseven/" .. string.sub( model, 27 );
    elseif ( string.sub( model, 8, 21 ) == "props_borealis" ) then
        new_model = "models/nseven/" .. string.sub( model, 23 );
    elseif ( string.sub( model, 1, 6 ) == "models" ) then
        new_model = "models/nseven/" .. string.sub( model, 8 );
    end;
    return new_model;
end;

local function propReplace( ply, model, ent, class )
    local new_model = propIsBreakable( model );
    if ( new_model ~= nil and util.IsValidModel( new_model ) ) then
        local class = class or "prop_physics";
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
            timer.Simple( 0.000001, function()
                undo.ReplaceEntity( ent, nEnt );
                cleanup.ReplaceEntity( ent, nEnt );
                ent:Remove();
            end );
        else
            timer.Simple( 0.000001, function()
                cleanup.ReplaceEntity( ent, nEnt );
                ent:Remove();
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
                        local new_model = propIsBreakable( ent:GetModel() );
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

hook.Add( "PlayerSpawnedProp", hookIndex.."PlayerSpawnedProp", function( ply, model, ent ) 
    if ( GetConVar("breakprops_active"):GetInt() <= 0 ) then return; end;
    if ( GetConVar("breakprops_change_playerspawn_prop"):GetInt() <= 0 ) then return; end;
    ply.Adv2DuplicatorEntities = ply.Adv2DuplicatorEntities or {};
    --[[ Заметка: как то нужно сделать эти ёбаные соединения ]]--
    -- ply.Adv2DuplicatorEntitiesConstruct = ply.Adv2DuplicatorEntitiesConstruct or {};
    --[[ Заметка: как то нужно сделать эти ёбаные соединения ]]--
    if ( ply.AdvDupe2 ~= nil ) then
        if ( ply.AdvDupe2.Pasting and GetConVar("breakprops_off_adv2"):GetInt() == 1  ) then 
            ent.Owner = ply;
            table.insert( ply.Adv2DuplicatorEntities, ent );
            local check = {};
            check.func = function()
                if ( not ply.AdvDupe2.Pasting ) then
                    if ( #ply.Adv2DuplicatorEntities ~= 0 ) then
                        for _, sEnt in pairs( ply.Adv2DuplicatorEntities ) do
                            if ( IsValid( sEnt ) ) then
                                propReplace( sEnt.Owner, sEnt:GetModel(), sEnt, sEnt:GetClass() );
                                --[[ Заметка: как то нужно сделать эти ёбаные соединения ]]--
                                -- local nProp = propReplace( sEnt.Owner, sEnt:GetModel(), sEnt, sEnt:GetClass() );
                                -- if ( nProp ~= NULL ) then
                                --     local entStorageTable = {};
                                --     local constraintStorageTable = {};
                                --     duplicator.GetAllConstrainedEntitiesAndConstraints( sEnt, entStorageTable, constraintStorageTable );
                                --     local tab = {  
                                --         OldEnt = sEnt,
                                --         NewEnt = nProp,
                                --         storage = entStorageTable,
                                --         constraint = constraintStorageTable,
                                --     };
                                --     tanle.insert( ply.Adv2DuplicatorEntitiesConstruct, tab );
                                -- end;
                                --[[ Заметка: как то нужно сделать эти ёбаные соединения ]]--
                            end;
                        end;
                        timer.Simple( 0.1, function()
                            if ( not ply.AdvDupe2.Pasting ) then
                                table.Empty( ply.Adv2DuplicatorEntities );
                            end;
                        end );
                    end;
                else
                    timer.Simple( 0.1, check.func );
                end;
            end;
            check.func();
        elseif ( not ply.AdvDupe2.Pasting and GetConVar("breakprops_off_adv2"):GetInt() == 1  ) then 
            propReplace( ply, model, ent, ent:GetClass() );
        elseif ( GetConVar("breakprops_off_adv2"):GetInt() == 0  ) then 
            propReplace( ply, model, ent, ent:GetClass() );
        end;
    else
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
            timer.Simple( 0.000001, function()
                local objects = ents.FindInSphere( getpos, 10 );
                --[[ Заметка: возможная система поиска пропов ]]--
                -- local objects = ents.FindInBox( obb_mins, obb_max );
                -- for _, v in pairs ( objects ) do
                --     print( v:GetModel() )
                -- end;
                --[[ Заметка: возможная система поиска пропов ]]--
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
                                if ( prop == objects[1] and #objects > 1 ) then
                                    more = true;
                                    undo.Create( "Prop" );
                                    undo.SetPlayer( owner );
                                end;
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