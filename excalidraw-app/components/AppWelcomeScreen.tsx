import { useI18n } from "@excalidraw/excalidraw/i18n";
import { WelcomeScreen } from "@excalidraw/excalidraw/index";
import { ExcalidrawLogo } from "@excalidraw/excalidraw/components/ExcalidrawLogo";
import React from "react";

const CutedrawLogo = () => (
  <div className="cutedraw-logo" aria-label="Cutedraw">
    <ExcalidrawLogo />
    <span className="cutedraw-logo__wordmark">CUTEDRAW</span>
  </div>
);

export const AppWelcomeScreen: React.FC<{
  onCollabDialogOpen: () => any;
  isCollabEnabled: boolean;
}> = React.memo((props) => {
  const { t } = useI18n();

  return (
    <WelcomeScreen>
      <WelcomeScreen.Hints.MenuHint>
        {t("welcomeScreen.app.menuHint")}
      </WelcomeScreen.Hints.MenuHint>
      <WelcomeScreen.Hints.ToolbarHint />
      <WelcomeScreen.Hints.HelpHint />
      <WelcomeScreen.Center>
        <WelcomeScreen.Center.Logo>
          <CutedrawLogo />
        </WelcomeScreen.Center.Logo>
        <WelcomeScreen.Center.Heading>
          {t("welcomeScreen.app.center_heading")}
          <br />
          {t("welcomeScreen.app.center_heading_line2")}
          <br />
          {t("welcomeScreen.app.center_heading_line3")}
        </WelcomeScreen.Center.Heading>
        <WelcomeScreen.Center.Menu>
          <WelcomeScreen.Center.MenuItemLoadScene />
          <WelcomeScreen.Center.MenuItemHelp />
          {props.isCollabEnabled && (
            <WelcomeScreen.Center.MenuItemLiveCollaborationTrigger
              onSelect={() => props.onCollabDialogOpen()}
            />
          )}
        </WelcomeScreen.Center.Menu>
      </WelcomeScreen.Center>
    </WelcomeScreen>
  );
});
