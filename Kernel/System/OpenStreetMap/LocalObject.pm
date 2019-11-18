# --
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# Copyright (C) 2019 Rother OSS GmbH, https://otrs.ch/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::OpenStreetMap::LocalObject;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::OpenStreetMap::Line - Backend for ITSMConfigItem classes linked to one location

=head1 DESCRIPTION

Functions to generate the map section and icon locations.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    my $BackendObject = $Kernel::OM->Get('Kernel::System::OpenStreetMap::LocalObject');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 GatherInfo()

Gathers location and icon info.

    my %Info = $BackendObject->GatherInfo(
        Class        => 'Class',
        BackendDef   => $BackendDef,
        IconPath     => 'var/httpd/htdocs/RotherOSS-OpenStreetMap/' # optional
        ConfigItemID => 123,                                        # optional: only consider ConfigItemID 123, instead of whole class
    );

=cut

sub GatherInfo {
    my ( $Self, %Param ) = @_;
    
    # check for needed data
    for my $Needed ( qw/BackendDef Class/ ) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    my @CIs;
    if ( $Param{ConfigItemID} ) {
        push @CIs, $ConfigItemObject->ConfigItemGet(
            ConfigItemID => $Param{ConfigItemID},
        );
    }
    else {
        my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
        my %ClassToID = reverse %{ $GeneralCatalogObject->ItemList(Class => 'ITSM::ConfigItem::Class') };

        push @CIs, @{ $ConfigItemObject->ConfigItemResultList(
            ClassID => $ClassToID{ $Param{Class} },
        ) };
    }

    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    # get the configurations for the class backends
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my %LinkBackendDef = map { $_->{Class} => $_ } values %{ $ConfigObject->Get('RotherOSSOpenStreetMap::ClassConfig') };

    my ( $From, $To, %Icons );
    CI:
    for my $ConfigItem ( @CIs ) {

        my $LinkList = $LinkObject->LinkListWithData(
            Object                          => 'ITSMConfigItem',
            Key                             => $ConfigItem->{ConfigItemID},
            State                           => 'Valid',
            UserID                          => 1,
        );

        my $LocationID;

        LINKS:
        for my $LTypes ( values %{ $LinkList } ) {
          for my $LDirs ( values %{ $LTypes } ) {
            for my $CINums ( values %{ $LDirs } ) {
              for my $LinkedItem ( values %{ $CINums } ) {

                if ( $LinkedItem->{Class} eq $Param{BackendDef}{LocationInfo}{LinkedClasses}[0] ) {
                    $LocationID = $LinkedItem->{ConfigItemID};
                    last LINKS;
                }

              }
            }
          }
        }

        my $BackendObject = $Kernel::OM->Get( $LinkBackendDef{ $Param{BackendDef}{LocationInfo}{LinkedClasses}[0] }{Backend} );

        my %Info = $BackendObject->GatherInfo(
            ConfigItemID => $LocationID,
            Class        => $Param{BackendDef}{LocationInfo}{LinkedClasses}[0],
            BackendDef   => $LinkBackendDef{ $Param{BackendDef}{LocationInfo}{LinkedClasses}[0] },
        );

        if ( !$Info{From} || !$Info{To} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "No coordinates found for linked ConfigItem: $LocationID!",
            );
            next CI;
        }

        # define coordinates
        if ( !$From ) {
            $From = [ $Info{From}[0], $Info{From}[1] ];
            $To   = [ $Info{To}[0],   $Info{To}[1] ];
        }
        else {
            if ( $From->[0] > $Info{From}[0] ) { $From->[0] = $Info{From}[0] }
            if ( $From->[1] > $Info{From}[1] ) { $From->[1] = $Info{From}[1] }
            if ( $To->[0]   < $Info{To}[0] )   { $To->[0]   = $Info{To}[0] }
            if ( $To->[1]   < $Info{To}[1] )   { $To->[1]   = $Info{To}[1] }
        }
        
        # add icon
#        push @{ $Icons{Path} },      $Param{BackendDef}{IconPath};
        push @{ $Icons{Path} },      $Info{Icons}{Path}[0];
        push @{ $Icons{Latitude} },  $Info{Icons}{Latitude}[0];
        push @{ $Icons{Longitude} }, $Info{Icons}{Longitude}[0];
        push @{ $Icons{Link} },      $Info{Icons}{Link}[0];
#        push @{ $Icons{Link} },      ( $Param{BackendDef}{LinkSelf} ) ? "Action=AgentITSMConfigItemZoom;ConfigItemID=$ConfigItem->{ConfigItemID}" : '';

    }

    return (
        From  => $From,
        To    => $To,
        Icons => \%Icons,
    );

}


1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
