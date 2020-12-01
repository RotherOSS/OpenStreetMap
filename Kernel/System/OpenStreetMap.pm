# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2020 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

package Kernel::System::OpenStreetMap;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::Config',
    'Kernel::System::ITSMConfigItem',
);

=head1 NAME

Kernel::System::OpenStreetMap

=head1 DESCRIPTION

Functions to generate the map section and icon locations.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    my $OSMObject = $Kernel::OM->Get('Kernel::System::OpenStreetMap');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 GenerateResponse()

Generates the Response containing all the info.

    my $Response = $OSMObject->GenerateResponse(
        OriginalAction => Action,
    );

=cut

sub GenerateResponse {
    my ( $Self, %Param ) = @_;

    my $ReturnErr = [
        {
            Name => 'From',
            Data => [ -10, -10 ],
        },
        {
            Name => 'To',
            Data => [ 10, 10 ],
        },
    ];

    # check for needed data
    if ( !defined $Param{OriginalAction} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need OriginalAction!',
        );
        return $ReturnErr;
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get the templates for all actions
    my $Templates = $ConfigObject->Get('OpenStreetMap::ActionConfig');
    if ( !$Templates ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => 'No ActionConfigs found!',
        );
        return $ReturnErr;
    }

    if ( $Param{OriginalAction} eq 'CommonAction' ) {    
        $Param{OriginalAction} = $Param{UserID} ? ( $ConfigObject->Get('Frontend::CommonParam')->{'Action'} || 'CommonAction' ) :
            ( $ConfigObject->Get('CustomerFrontend::CommonParam')->{'Action'} || 'CustomerCommonAction' );
    }

    # get the map config for the current action
    my $MapConfig;
    TEMPLATE:
    for my $CurrConf ( values %{$Templates} ) {
        if ( $CurrConf->{Action} eq $Param{OriginalAction} ) {
            $MapConfig = $CurrConf;
            last TEMPLATE;
        }
    }

    if ( !$MapConfig ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "No ActionConfig found for $Param{OriginalAction}!",
        );
        return $ReturnErr;
    }

    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $CustomerGroupObject  = ( $Param{CustomerUserID} && $ConfigObject->Get('CustomerGroupSupport') ) ? $Kernel::OM->Get('Kernel::System::CustomerGroup') : undef;

    # get class list
    my %ClassIDs;
    {
        my $ClassList = $GeneralCatalogObject->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        );
        %ClassIDs = reverse %{ $ClassList };
    }

    # get the configurations for the class backends
    my %BackendDef = map { $_->{Class} => $_ } values %{ $ConfigObject->Get('OpenStreetMap::ClassConfig') };

    my ( $Return, %Icons, %Lines );
    CATEGORY:
    for my $Category ( @{ $MapConfig->{Show} } ) {
        my %Data;
        if ( $Category eq 'Self' ) {
            %Data = $Self->_ClassGet(
                %Param,
                BackendDef => \%BackendDef,
            );

            if ( !$Data{Class} ) {
                return $ReturnErr;
            }

            # Add ConfigItemID or similar
            %Data = (
                %Param,
                %Data,
            );
        }
        else {
            %Data = (
                Class   => $Category,
                ClassID => $ClassIDs{ $Category },
            );
        }

        # show items only if user has access rights
        my $HasAccess;
        # agents
        if ( $Param{UserID} ) {
            $HasAccess = $ConfigItemObject->Permission(
                Scope   => 'Class',
                ClassID => $Data{ClassID},
                UserID  => $Param{UserID},
                Type    => 'ro',
                LogNo   => 1,
            );
        }

        # customer users with group support
        elsif ( $CustomerGroupObject ) {
            my $ClassItem = $GeneralCatalogObject->ItemGet(
                ItemID => $Data{ClassID},
            );
            # get user groups
            my @GroupIDs = $CustomerGroupObject->GroupMemberList(
                UserID => $Param{CustomerUserID},
                Type   => 'ro',
                Result => 'ID',
            );
            # looking for group id
            GROUP:
            for my $GroupID (@GroupIDs) {
                if ( $ClassItem->{Permission} && $GroupID eq $ClassItem->{Permission} ) {
                    $HasAccess = 1;
                    last GROUP;
                }
            }
        }

        # customer users without group support (show everything which is configured)
        elsif ( $Param{CustomerUserID} ) {
            $HasAccess = 1;
        }

        next CATEGORY if !$HasAccess;

        my %Info = $Kernel::OM->Get( $BackendDef{ $Data{Class} }{Backend} )->GatherInfo(
            %Data,
            BackendDef => $BackendDef{ $Data{Class} },
        );

        # Adjust map cutout
        if ( !defined $Return && %Info ) {
            $Return = [
                {
                    Data => $Info{From},
                    Name => 'From',
                },
                {
                    Data => $Info{To},
                    Name => 'To',
                }
            ];
        }
        elsif (%Info) {
            if ( $Info{From}[0] < $Return->[0]->{Data}->[0] ) { $Return->[0]->{Data}->[0] = $Info{From}[0] }
            if ( $Info{From}[1] < $Return->[0]->{Data}->[1] ) { $Return->[0]->{Data}->[1] = $Info{From}[1] }
            if ( $Info{To}[0] > $Return->[1]->{Data}->[0] )   { $Return->[1]->{Data}->[0] = $Info{To}[0] }
            if ( $Info{To}[1] > $Return->[1]->{Data}->[1] )   { $Return->[1]->{Data}->[1] = $Info{To}[1] }
        }
        else {
             next CATEGORY;
        }

        # gather icon info
        if ( $Info{Icons} ) {
            if ( $Info{Icons}{Latitude} && $Info{Icons}{Longitude} ) {
                for my $Key (qw/Latitude Longitude Path Link Description/) {
                    if ( defined $Info{Icons}{$Key} ) {
                        for my $i ( 0 .. $#{ $Info{Icons}{Latitude} } ) {
                            push @{ $Icons{$Key} }, $Info{Icons}{$Key}[$i];
                        }
                    }
                    else {
                        for my $i ( 0 .. $#{ $Info{Icons}{Latitude} } ) {
                            push @{ $Icons{$Key} }, "";
                        }
                    }
                }
            }
        }

        # gather line info
        if ( $Info{Lines} ) {
            if ( $Info{Lines}{From0} ) {
                for my $Key (qw/From0 To0 From1 To1 Color Link Description Weight/) {
                    if ( defined $Info{Lines}{$Key} ) {
                        for my $i ( 0 .. $#{ $Info{Lines}{From0} } ) {
                            push @{ $Lines{$Key} }, $Info{Lines}{$Key}[$i];
                        }
                    }
                    else {
                        for my $i ( 0 .. $#{ $Info{Lines}{From0} } ) {
                            push @{ $Lines{$Key} }, "";
                        }
                    }
                }
            }
        }
    }

    if ( !defined $Return ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => "No map data provided! ( $Param{OriginalAction} )",
        );
        return $ReturnErr;
    }

    # if no coordinates where provided
    for my $i ( 0, 1 ) {
        for my $j ( 0, 1 ) {
            $Return->[$i]->{Data}->[$j] //= 0;
        }
    }

    # margin is either a fraction of the map cutout, or, if it is to small, the predefined margin
    my $Margin = (
        sort { $a <=> $b } (
            $MapConfig->{Margin},
            0.08 * ( $Return->[0]->{Data}->[1] - $Return->[0]->{Data}->[0] ),
            0.08 * ( $Return->[1]->{Data}->[1] - $Return->[1]->{Data}->[0] )
        )
    )[-1];

    $Return->[0]->{Data}->[0] -= $Margin;
    $Return->[0]->{Data}->[1] -= $Margin;
    $Return->[1]->{Data}->[0] += $Margin;
    $Return->[1]->{Data}->[1] += $Margin;

    if (%Icons) {
        push @{$Return}, {
            Name => 'Icons',
            Data => \%Icons,
        };
    }
    if (%Lines) {
        push @{$Return}, {
            Name => 'Lines',
            Data => \%Lines,
        };
    }

    return $Return;

}

=head2 _ClassGet()

Provides the class in dependence of the site visited.

    my ( $ClassID, $Class ) = $OSMObject->_ClassGet(
        OriginalAction => 'Action',
        %GetParam,
    );

=cut

sub _ClassGet {
    my ( $Self, %Param ) = @_;

    # check for needed data
    for my $Needed (qw/OriginalAction BackendDef/) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( $Param{OriginalAction} eq 'AgentITSMConfigItemZoom' ) {
        if ( !defined $Param{ConfigItemID} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need ConfigItemID!',
            );
            return;
        }

        my $CI = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
            ConfigItemID => $Param{ConfigItemID},
        );

        if ( !$Param{BackendDef}{ $CI->{Class} } ) {
            return;
        }

        return ( 
            ClassID => $CI->{ClassID},
            Class   => $CI->{Class},
        );
    }

    return;

}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTOBO project (L<https://otobo.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.


=cut
