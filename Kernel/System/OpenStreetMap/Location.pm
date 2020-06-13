# --
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# Copyright (C) 2019 Rother OSS GmbH, https://otrs.ch/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::OpenStreetMap::Location;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
);

=head1 NAME

Kernel::System::OpenStreetMap::Location - Backend for ITSMConfigItem::Location classes containing GPSLongitude and GPSLatitude

=head1 DESCRIPTION

Functions to generate the map section and icon locations.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    my $BackendObject = $Kernel::OM->Get('Kernel::System::OpenStreetMap::Location');

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
        Class        => 'Location_Class',
        BackendDef   => $BackendDef,
        IconPath     => 'var/httpd/htdocs/RotherOSS-OpenStreetMap/' # optional
        ConfigItemID => 123,                                        # optional: only consider ConfigItemID 123, instead of whole class
    );

=cut

sub GatherInfo {
    my ( $Self, %Param ) = @_;

    # check for needed data
    for my $Needed (qw/BackendDef Class/) {
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
        my %ClassToID            = reverse %{ $GeneralCatalogObject->ItemList( Class => 'ITSM::ConfigItem::Class' ) };

        push @CIs, @{
            $ConfigItemObject->ConfigItemResultList(
                ClassID => $ClassToID{ $Param{Class} },
            )
        };
    }

    my ( $From, $To, %Icons );
    CI:
    for my $ConfigItem (@CIs) {

        my $Version = $ConfigItemObject->VersionGet(
            VersionID => $ConfigItem->{LastVersionID},
        );

        my $Latitude  = $Version->{XMLData}->[1]->{Version}->[1]->{GPSLatitude}->[1]->{Content}  || undef;
        my $Longitude = $Version->{XMLData}->[1]->{Version}->[1]->{GPSLongitude}->[1]->{Content} || undef;

        if ( !defined $Latitude || !defined $Longitude ) {
            next CI;
        }

        # define coordinates
        if ( !$From ) {
            $From = [ $Latitude, $Longitude ];
            $To   = [ $Latitude, $Longitude ];
        }
        else {
            if ( $From->[0] > $Latitude )  { $From->[0] = $Latitude }
            if ( $From->[1] > $Longitude ) { $From->[1] = $Longitude }
            if ( $To->[0] < $Latitude )    { $To->[0]   = $Latitude }
            if ( $To->[1] < $Longitude )   { $To->[1]   = $Longitude }
        }

        # place Icon
        if ( $Param{BackendDef}{IconPath} ) {
            push @{ $Icons{Path} },      $Param{BackendDef}{IconPath};
            push @{ $Icons{Latitude} },  $Latitude;
            push @{ $Icons{Longitude} }, $Longitude;
            push @{ $Icons{Link} },
                ( $Param{BackendDef}{LinkSelf} )
                ? "Action=AgentITSMConfigItemZoom;ConfigItemID=$ConfigItem->{ConfigItemID}"
                : '';
        }
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
