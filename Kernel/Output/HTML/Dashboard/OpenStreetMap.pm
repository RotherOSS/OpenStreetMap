# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2012-2019 Znuny GmbH, http://znuny.com/
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
