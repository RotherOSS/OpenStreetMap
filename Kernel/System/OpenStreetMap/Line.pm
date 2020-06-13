# --
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# Copyright (C) 2019 Rother OSS GmbH, https://otrs.ch/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::OpenStreetMap::Line;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::Config',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::LinkObject',
);

=head1 NAME

Kernel::System::OpenStreetMap::Line - Backend for ITSMConfigItem classes linked to two locations

=head1 DESCRIPTION

Functions to generate the map section and icon locations.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    my $BackendObject = $Kernel::OM->Get('Kernel::System::OpenStreetMap::Line');

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
        Class        => 'Line_Class',
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

    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    # get the configurations for the class backends
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my %LinkBackendDef
        = map { $_->{Class} => $_ } values %{ $ConfigObject->Get('RotherOSSOpenStreetMap::ClassConfig') };

    # color definitions
    my $IncidentStateColors;
    if ( $Param{BackendDef}{LineColor} eq "IncidentState" ) {
        $IncidentStateColors = $ConfigObject->Get('RotherOSSOpenStreetMap::IncidentStateColors');
    }

    #use Data::Dumper;
    #print STDERR "vo60 - CIs: ".Dumper(\@CIs);
    my ( $From, $To, %Icons, %Lines );
    CI:
    for my $ConfigItem (@CIs) {

        my $LinkList = $LinkObject->LinkListWithData(
            Object => 'ITSMConfigItem',
            Key    => $ConfigItem->{ConfigItemID},
            State  => 'Valid',
            UserID => 1,
        );

        my @Ends;

        LINKS:
        for my $LTypes ( values %{$LinkList} ) {
            for my $LDirs ( values %{$LTypes} ) {
                for my $CINums ( values %{$LDirs} ) {
                    for my $LinkedItem ( values %{$CINums} ) {

                        if ( !$Ends[0] && $LinkedItem->{Class} eq $Param{BackendDef}{LocationInfo}{LinkedClasses}[0] ) {
                            $Ends[0] = $LinkedItem->{ConfigItemID};
                            if ( $Ends[1] ) {
                                last LINKS;
                            }
                        }
                        elsif (
                            !$Ends[1]
                            && $LinkedItem->{Class} eq $Param{BackendDef}{LocationInfo}{LinkedClasses}[1]
                            )
                        {
                            $Ends[1] = $LinkedItem->{ConfigItemID};
                            if ( $Ends[0] ) {
                                last LINKS;
                            }
                        }

                    }
                }
            }
        }

        if ( @Ends != 2 ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need two ends!",
            );
            return;
        }

        my @Info;
        for my $i ( 0, 1 ) {
            my $BackendObject
                = $Kernel::OM->Get( $LinkBackendDef{ $Param{BackendDef}{LocationInfo}{LinkedClasses}[$i] }{Backend} );

            %{ $Info[$i] } = $BackendObject->GatherInfo(
                ConfigItemID => $Ends[$i],
                Class        => $Param{BackendDef}{LocationInfo}{LinkedClasses}[$i],
                BackendDef   => $LinkBackendDef{ $Param{BackendDef}{LocationInfo}{LinkedClasses}[$i] },
            );

            if ( !$Info[$i]{From} || !$Info[$i]{To} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "No coordinates found for linked ConfigItem: $Ends[$i]!",
                );
                next CI;
            }
        }

        for my $i ( 0, 1 ) {

            # define coordinates
            if ( !$From ) {
                $From = [ $Info[$i]{From}[0], $Info[$i]{From}[1] ];
                $To   = [ $Info[$i]{To}[0],   $Info[$i]{To}[1] ];
            }
            else {
                if ( $From->[0] > $Info[$i]{From}[0] ) { $From->[0] = $Info[$i]{From}[0] }
                if ( $From->[1] > $Info[$i]{From}[1] ) { $From->[1] = $Info[$i]{From}[1] }
                if ( $To->[0] < $Info[$i]{To}[0] )     { $To->[0]   = $Info[$i]{To}[0] }
                if ( $To->[1] < $Info[$i]{To}[1] )     { $To->[1]   = $Info[$i]{To}[1] }
            }

            # add icons if only this ConfigItem is shown
            if ( $Param{ConfigItemID} && $Info[$i]{Icons} ) {
                for my $Attr (qw/Path Latitude Longitude Link/) {
                    push @{ $Icons{$Attr} }, @{ $Info[$i]{Icons}{$Attr} };
                }
            }
        }

        #use Data::Dumper;
        #print STDERR "vo60 - CI: ".Dumper($ConfigItem);
        # add line
        push @{ $Lines{From0} }, $Info[0]{From}[0];
        push @{ $Lines{From1} }, $Info[0]{From}[1];
        push @{ $Lines{To0} },   $Info[1]{From}[0];
        push @{ $Lines{To1} },   $Info[1]{From}[1];
        push @{ $Lines{Color} },
            $IncidentStateColors
            ? $IncidentStateColors->{ $ConfigItem->{CurInciState} } || "#552244"
            : $Param{BackendDef}{LineColor} || "#552244";
        push @{ $Lines{Weight} }, $Param{BackendDef}{LineWidth} || 5;
        push @{ $Lines{Link} },
            ( $Param{BackendDef}{LinkSelf} )
            ? "Action=AgentITSMConfigItemZoom;ConfigItemID=$ConfigItem->{ConfigItemID}"
            : '';

    }

    #use Data::Dumper;
    #print STDERR "vo60 - Icons: ".Dumper(\%Icons);
    #print STDERR "vo60 - Lines: ".Dumper(\%Lines);

    return (
        From  => $From,
        To    => $To,
        Icons => \%Icons,
        Lines => \%Lines,
    );

}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
