# --
# OTOBO is a web-based ticketing system for service organisations.
# --
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

package Kernel::Modules::OpenStreetMap;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get params
    my %GetParam;

    for my $Attribute ( $ParamObject->GetParamNames() ) {
        $GetParam{$Attribute} = $ParamObject->GetParam( Param => $Attribute );
    }

    # AJAX function call
    if ( $GetParam{OriginalAction} ) {

        # get icon and location info
        my $OSMObject = $Kernel::OM->Get('Kernel::System::OpenStreetMap');

        my $JSON = $LayoutObject->BuildSelectionJSON(
            $OSMObject->GenerateResponse(%GetParam),
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # show module page
    else {

        my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

        # store last screen, used for backlinks
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => 'LastScreenView',
            Value     => $Self->{RequestedURL},
        );

        # get layout object
        my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

        #        # investigate refresh
        #        my $Refresh = $Self->{UserRefreshTime} ? 60 * $Self->{UserRefreshTime} : undef;

        # output header
        my $Output = $LayoutObject->Header(
            Title => Translatable('OpenStreetMap'),

            #            Refresh => $Refresh,
        );
        $Output .= $LayoutObject->NavigationBar();

        $Output .= $LayoutObject->Output(
            TemplateFile => 'OpenStreetMap',
        );

        # add footer
        $Output .= $LayoutObject->Footer();

        return $Output;

    }

}

1;
