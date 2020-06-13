# --
# Copyright (C) 2012-2019 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Output::HTML::Dashboard::OpenStreetMap;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    #    $Self->{PrefKeyShown}    = 'UserDashboardPref' . $Self->{Name} . '-Shown';
    #    $Self->{PrefKeyShownMax} = 'UserDashboardPref' . $Self->{Name} . '-ShownMax';

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;
    #
    #    # disable params
    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    #    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    #    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my %Config = (
        %{ $Self->{Config} },

        #        Link                      => $LayoutObject->{Baselink} . 'Action=AgentCustomerMap',
        #        LinkTitle                 => 'Detail',
        #        PreferencesReloadRequired => 1,
    );

    return %Config;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'ContentLargeOpenStreetMap',
        Data => {
            Width  => '100%',
            Height => '400px',
        },
    );

    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardOpenStreetMap',
        Data         => {
        },
    );

    return $Content;
}

1;
