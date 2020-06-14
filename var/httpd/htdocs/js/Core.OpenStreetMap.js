// --
// Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
// Copyright (C) 2019 Rother OSS GmbH, https://otrs.ch/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (GPL). If you
// did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
// --

"use strict";

var Core = Core || {};

Core.OpenStreetMap = (function (TargetNS) {

    var CanvasID = 'openstreetmap-canvas';

    TargetNS.Init = function () {
        if ( $( "#" + CanvasID ).length > 0 ) {
            TargetNS.CreateMap();
        }
    };

    TargetNS.CreateMap = function () {
        // CSS laden
        TargetNS.LoadCSS("/otrs-web/skins/Agent/default/css/thirdparty/leaflet-1.4.0/leaflet.css");

        // Leafletscript laden
        TargetNS.LoadScript("/otrs-web/js/thirdparty/leaflet-1.4.0/leaflet.js", TargetNS.MapScript);
    };

    TargetNS.MapScript = function () {

        var mapcanvas = document.querySelector( "#" + CanvasID );
        mapcanvas.innerHTML = "";

        // Karten anlegen

        var osm = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
//        var osm = L.tileLayer('https://maps.otrs.ch/hot/{z}/{x}/{y}.png', {
            maxZoom: 10,
            attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/" target="_blank">OpenStreetMap</a> and contributors <a href="https://creativecommons.org/licenses/by-sa/2.0/" target="_blank">CC-BY-SA</a>'
        });

            var map = L.map(mapcanvas, { layers: osm, tap: false } ) ;

        // Mit Maßstab

            L.control.scale({imperial:false}).addTo(map);

        //Kartenausschnitt wählen
        var Data = {};

        // gather info from url (need ConfigItemID)
        var hash;
        var hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split(';');
        for(var i = 0; i < hashes.length; i++)
        {
            hash = hashes[i].split('=');
            Data[hash[0]] = hash[1];
        }

        if ( Data['Action'] != undefined ) {
            Data['OriginalAction'] = Data['Action'];
        }
        else {
            // (Customer)Frontend::CommonParam###Action
            Data['OriginalAction'] = 'CommonAction';
        }
        Data['Action'] = 'OpenStreetMap';

        Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function(Response){

            var bounds = [ [ Response['From'][0][0], Response['From'][1][0] ], [ Response['To'][0][0], Response['To'][1][0] ] ];

            // link function creator to have constant Urls for old browsers, too
            function GetLinkOpener( Url ) {
                return function() {
                    window.open( Url, "_self" );
                };
            }

            // place icons
            if ( Response['Icons'] ) {
                var Icons = {};

                // map the unordered Response array to an attribute hash
                Response['Icons'].map(function(n){ Icons[ n[0] ] = n[1] });

                for (var i = 0; i < Icons['Latitude'].length ; i++) {
                    var Icon;
                    // add to map
                    if ( Icons['Path'][i] == '' ) {
                        Icon = L.marker([Icons['Latitude'][i], Icons['Longitude'][i]]).addTo(map);
                    }
                    else {
                        var Logo = L.icon({ iconUrl: Icons['Path'][i], iconSize: [10, 15], iconAnchor: [5, 15] });
                        Icon = L.marker([Icons['Latitude'][i], Icons['Longitude'][i]], {icon: Logo});
                        Icon.addTo(map);
                    }

                    // link
                    if ( Icons['Link'][i] != '' ) {
                        var OpenUrl = GetLinkOpener( Core.Config.Get('Baselink')+Icons['Link'][i] );
                        Icon.on( "click", OpenUrl );
                    }
                    // description
                    else if ( Icons['Description'][i] != '' ) {
                        Icon.bindPopup( Icons['Description'][i] );
                    }
                }
            }

            // draw lines
            if ( Response['Lines'] ) {
                // map the unordered Response array to an attribute hash
                var Lines = {};
                Response['Lines'].map(function(n){ Lines[ n[0] ] = n[1] });
                for (var i = 0; i < Lines['From0'].length ; i++) {

                    // add to map
                    var Line = L.polyline([ [Lines['From0'][i], Lines['From1'][i]], [Lines['To0'][i], Lines['To1'][i]] ], {color: Lines['Color'][i], weight: Lines['Weight'][i], opacity: 1} );
                    Line.addTo(map);

                    // link
                    if ( Lines['Link'][i] != '' ) {
                        var OpenUrl = GetLinkOpener( Core.Config.Get('Baselink')+Lines['Link'][i] );
                        Line.on( "click", OpenUrl );
                    }
                    // description
                    else if ( Lines['Description'][i] != '' ) {
                        Line.bindPopup( Lines['Description'][i] );
                    }

                }
            }

            // scale map
                map.fitBounds( bounds );

            // Karte bei resize neu skalieren
                map.on("resize", function(e){
                    map.fitBounds( bounds );
                });

        });

    };

    TargetNS.LoadScript = function (url,callback) {
        var scr = document.createElement('script');
        scr.type = "text/javascript";
        scr.async = "async";
        if(typeof(callback)=="function") {
            scr.onloadDone = false;
            scr.onload = function() {
                if ( !scr.onloadDone ) {
                    scr.onloadDone = true;
                    callback();
                }
            };
            scr.onreadystatechange = function() {
                if ( ( "loaded" === scr.readyState || "complete" === scr.readyState ) && !scr.onloadDone ) {
                    scr.onloadDone = true;
                    callback();
                }
            }
        }
        scr.src = url;
        document.getElementsByTagName('head')[0].appendChild(scr);
    }; // LoadScript

    TargetNS.LoadCSS = function (url) {
        var l = document.createElement("link");
        l.type = "text/css";
        l.rel = "stylesheet";
        l.href = url;
        document.getElementsByTagName("head")[0].appendChild(l);
    }; // LoadCSS

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;

}(Core.OpenStreetMap || {}));
