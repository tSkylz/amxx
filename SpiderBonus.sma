#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <sqlx>

new const szPlugin[ ][ ] = { "ADDON: Spider Bonus", "1.0", "Alan." };
new const szPrefix[ ] = "^4[Asylum - Gamers]^1";

new const szNameDb[ ] = "db_spider_bonus";
new const szTable[ ] = "tb_spider_bonus";

/* ================================================================ */

enum { LOAD_DATA, SAVE_DATA, INSERT_DATA, TOP15_DATA, RANK_DATA };

#define SPIDER_MINS { -12.44, 0.07, -18.83 }
#define SPIDER_MAXS { 16.44, 14.75, 18.34 }

new const szClassNameEnt[ ] = "sb_spider";
new const szModelEnt[ ] = "models/asylumgamers/chick.mdl";

new g_szPlayerName[ MAX_PLAYERS + 1 ][ MAX_NAME_LENGTH ];
new g_iSpider[ MAX_PLAYERS + 1 ];
new Handle:g_hTuple, Handle:g_hConnect;
new g_TopEmpty;

/* ================================================================ */

public plugin_precache( ) precache_model( szModelEnt );

public plugin_init( ) {
	register_plugin( szPlugin[ 0 ], szPlugin[ 1 ], szPlugin[ 2 ] );

	register_event( "HLTV", "ev_RoundStart", "a", "1=0", "2=0" );

	RegisterHam( Ham_Killed, "player", "fw_PlayerKilled" );
	register_forward( FM_Touch, "fw_Touch" );

	register_clcmd( "say /ag_top", "fn_ShowTop" );
	register_clcmd( "say /ag_rank", "fn_PrintRank" );

	SQL_Init( );
}

public client_putinserver( id ) {
	get_user_name( id, g_szPlayerName[ id ], charsmax( g_szPlayerName[ ] ) );

	g_iSpider[ id ] = 0;

	fn_ManageData( id, 1 );
}
public client_disconnected( id ) fn_ManageData( id, 2 );

/* ================================================================ */

public ev_RoundStart( ) {
	new ent;

	while( ( ent = find_ent_by_class( ent, szClassNameEnt ) ) ) remove_entity( ent );

	for( new i = 1; i < get_maxplayers( ); i++ ) {
		if( !is_user_connected( i ) ) continue;

		fn_ManageData( i, 2 );
	}
}

public fw_PlayerKilled( victim, attacker, shouldgib ) {
	if( victim == attacker || !is_user_connected( victim ) || !is_user_connected( attacker ) ) return HAM_IGNORED;

	new iOrigin[ 3 ]; get_user_origin( victim, iOrigin, 0 );
	fn_CreateSpider( iOrigin );

	return HAM_IGNORED;
}
public fw_Touch( toucher, touched ) {
	if( !is_user_alive( toucher ) || !is_valid_ent( touched ) ) return FMRES_IGNORED;

	new szClassName[ 12 ]; entity_get_string( touched, EV_SZ_classname, szClassName, charsmax( szClassName ) );

	if( !equal( szClassName, szClassNameEnt ) ) return FMRES_IGNORED;

	client_print_color( toucher, print_team_default, "%s Agarraste una araña.", szPrefix );
	g_iSpider[ toucher ]++;

	remove_entity( touched );

	return FMRES_IGNORED;
}

/* ================================================================ */

public fn_CreateSpider( iOrigin[ 3 ] ) {
	new iEnt = create_entity( "info_target" );

	entity_set_string( iEnt, EV_SZ_classname, szClassNameEnt );
	entity_set_model( iEnt, szModelEnt );
	entity_set_size( iEnt, Float:SPIDER_MINS, Float:SPIDER_MAXS );
	entity_set_int( iEnt, EV_INT_solid, SOLID_BBOX );
	entity_set_int( iEnt, EV_INT_movetype, MOVETYPE_FLY );

	new Float:fOrigin[ 3 ];
	IVecFVec( iOrigin, fOrigin );
	fOrigin[ 2 ] -= 27.5
	entity_set_vector( iEnt, EV_VEC_origin, fOrigin );
	drop_to_floor( iEnt );

	entity_set_int( iEnt, EV_INT_renderfx, kRenderFxGlowShell );
	entity_set_vector( iEnt, EV_VEC_rendercolor, Float:{ 255.0, 0.0, 0.0 } );

	drop_to_floor( iEnt );
}
public fn_ManageData( id, type ) {
	if( type == 1 ) 
		st_Query( id, LOAD_DATA, "SELECT * FROM '%s' WHERE Name = ^"%s^"", szTable, g_szPlayerName[ id ] );
	if( type == 2 )
		st_Query( id, SAVE_DATA, "UPDATE '%s' SET Spiders = '%d' WHERE Name = ^"%s^"", szTable, g_iSpider[ id ], g_szPlayerName[ id ] );
}
public fn_ShowTop( id ) {
	if( g_TopEmpty ) {
		client_print_color( id, print_team_default, "%s El^4 Top^1 está vacío.", szPrefix );
		return PLUGIN_HANDLED;
	}
	
	fn_MotdTop( id );
	
	return PLUGIN_HANDLED;
}
public fn_MotdTop( id ) {
	st_Query( id, TOP15_DATA, "SELECT Name, Spiders FROM '%s' ORDER BY Spiders DESC LIMIT 0, 10", szTable );
	return PLUGIN_HANDLED;
}
public fn_PrintRank( id ) {
	new Handle:iQuery, iCount, szName[ MAX_NAME_LENGTH ];
	iQuery = SQL_PrepareQuery( g_hConnect, "SELECT Name FROM '%s' ORDER BY Spiders DESC", szTable );

	if( SQL_Execute( iQuery ) ) {
		while( SQL_MoreResults( iQuery ) ) {
			iCount++;

			SQL_ReadResult( iQuery, 0, szName, charsmax( szName ) );

			if( equal( g_szPlayerName[ id ], szName ) ) {
				client_print_color( id, print_team_default, "%s Tu rank es^4 %d^1 con^4 %d^1 arañas.", szPrefix, iCount, g_iSpider[ id ] );
				break;
			}

			SQL_NextRow( iQuery );
		}
	}

	return PLUGIN_HANDLED;
}

/* ======================================================= */

public SQL_Handler( failstate, Handle:Query, Error[ ], szError, Data[ ], szData[ ], Float:time ) {
	static id; id = Data[ 0 ];

	if( !is_user_connected( id ) ) return;

	if( failstate == TQUERY_CONNECT_FAILED || failstate == TQUERY_QUERY_FAILED )
		log_to_file( "ERROR_SQL.txt", "Error %d:%d", szError, Error );

	switch( Data[ 1 ] ) {
		case LOAD_DATA: {
			if( SQL_NumResults( Query ) ) g_iSpider[ id ] = SQL_ReadResult( Query, 1 );
			else 
				st_Query( id, INSERT_DATA, "INSERT INTO '%s' (Name) VALUES (^"%s^")", szTable, g_szPlayerName[ id ] );
		}
		case SAVE_DATA: {
			if( failstate < TQUERY_SUCCESS ) client_print_color( id, print_team_default, "%s Error al guardar tús datos.", szPrefix );
			else client_print_color( id, print_team_default, "%s Datos guardados exitosamente.", szPrefix );
		}
		case INSERT_DATA: {
			if( failstate < TQUERY_SUCCESS ) return;
			else fn_ManageData( id, 1 );
		}
		case TOP15_DATA: {
			if( SQL_NumResults( Query ) ) {
				g_TopEmpty = false;

				new iPosition, szName[ MAX_NAME_LENGTH ], iSpiders;
				static len, szBuffer[ 2368 ];
				len = 0;

				len = format( szBuffer[ len ], charsmax( szBuffer ) - len, "<STYLE>body{background:#232323;color:#cfcbc2;font-family:sans-serif}table{width:100%%;line-height:160%%;font-size:12px}\
					.q{border:1px solid #4a4945}.b{background:#2a2a2a}</STYLE><table cellpadding=2 cellspacing=0 border=0>" );
				len += format( szBuffer[ len ], charsmax( szBuffer ) - len, "<tr align=center bgcolor=#52697B><th width=5%%> # <th width=22%% align=left> Nombre <th width=10%%> Ara&ntilde;as" );

				while( SQL_MoreResults( Query ) ) {
            		++iPosition;

            		SQL_ReadResult( Query, 0, szName, charsmax( szName ) );
            		iSpiders = SQL_ReadResult( Query, 1 );

            		len += format( szBuffer[ len ], charsmax( szBuffer ) - len, "<tr align=center%s><td> %d <td align=left> %s <td> %d",
            			( ( iPosition%2 )==0 ) ? "" : " bgcolor=#2f3030", iPosition, szName, iSpiders );
            		SQL_NextRow( Query );
            	}

				show_motd( id, szBuffer, "ASYLUM-GAMERS TOP" );
			} else
				g_TopEmpty = true;
		}
	}
}

public SQL_Init( ) {
	new get_type[ 12 ], table[ 1000 ], len, szError[ 256 ], iError;
	
	SQL_SetAffinity( "sqlite" );
	SQL_GetAffinity( get_type, sizeof( get_type ) );
	
	if( !equal( get_type, "sqlite" ) ) {
		log_to_file( "ERROR_SQL.txt", "Error al conectar." );
		return pause( "a" );
	}
	
	g_hTuple = SQL_MakeDbTuple( "", "", "", szNameDb );
	g_hConnect = SQL_Connect( g_hTuple, iError, szError, sizeof ( szError ) - 1 );
	
	len = 0;
	len += formatex( table[ len ], charsmax( table ) - len, "CREATE TABLE IF NOT EXISTS '%s'", szTable );
	len += formatex( table[ len ], charsmax( table ) - len, "( Name varchar(32) NOT NULL UNIQUE PRIMARY KEY," );
	len += formatex( table[ len ], charsmax( table ) - len, "Spiders int NOT NULL DEFAULT '0' )" );
	SQL_ThreadQuery( g_hTuple, "SQL_CreateTable", table );
	
	return PLUGIN_CONTINUE;
}

public SQL_CreateTable( failstate, Handle:query, error[], szerror, data[], szdata, Float:time ) {
	switch( failstate ) {
		case TQUERY_CONNECT_FAILED: log_to_file( "SQL_TConnection.txt", "Error: %i - %s", szerror, error );
		case TQUERY_QUERY_FAILED: log_to_file( "SQL_TQuery.txt", "Error: %i - %s", szerror, error );
	}
}

public plugin_end( ) if( g_hTuple ) SQL_FreeHandle( g_hTuple );

/* ======================================================= */

public st_Query( id, status, const buffer[ ], any:... ) {
	new query[ 1024 ], data[ 2 ];
	
	data[ 0 ] = id;
	data[ 1 ] = status;
	
	vformat( query, charsmax( query ), buffer, 4 );
	SQL_ThreadQuery( g_hTuple, "SQL_Handler", query, data, 2 );
}