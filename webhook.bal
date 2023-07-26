import ballerinax/trigger.github;
import ballerina/http;
import wso2/choreo.sendemail as email;
import ballerinax/googleapis.sheets as sheets;
import ballerina/log;

configurable github:ListenerConfig gitHubListenerConfig = ?;

// Types
type OAuth2RefreshTokenGrantConfig record {
    string clientId;
    string clientSecret;
    string refreshToken;
    string refreshUrl = "https://www.googleapis.com/oauth2/v3/token";
};

// Constants
const HEADINGS_ROW = 1;

final string[] & readonly columnNames = [
    "Issue Link",
    "Issue Number",
    "Issue Title",
    "Issue Creator",
    "Issue Created At"
];

// Email recepient address
configurable string recipientAddress = ?;

// Google sheets configuration parameters
configurable OAuth2RefreshTokenGrantConfig GSheetAuthConfig = ?;
configurable string spreadsheetId = ?;
configurable string worksheetName = ?;

listener http:Listener httpListener = new(8090);
listener github:Listener gitHubListener =  new(gitHubListenerConfig,httpListener);

@display { label: "GitHub New Issue to Gmail and Google Sheets Row" }
service github:IssuesService on gitHubListener {

    // This function is invoked when a new issue is created
    remote function onOpened(github:IssuesEvent payload ) returns error? {

      sheets:Client spreadsheetClient = check new ({
          auth: {
            clientId: GSheetAuthConfig.clientId,
            clientSecret: GSheetAuthConfig.clientSecret,
            refreshToken: GSheetAuthConfig.refreshToken,
            refreshUrl: GSheetAuthConfig.refreshUrl
          }
      });

      string issueTitle = payload.issue.title;
      string issueBody = payload.issue.body ?: "";
      int issueNumber = payload.issue.number;

      email:Client emailClient = check new ();
      string sendEmailResponse = check emailClient->sendEmail(recipientAddress, "New Issue Created", "Issue Title: " + issueNumber.toString() + ":" + issueTitle + " Issue Body: " + issueBody);
      log:printInfo("Email sent to " + recipientAddress + " with response: " + sendEmailResponse);

      sheets:Row existingColumnNames = check spreadsheetClient->getRow(spreadsheetId, worksheetName, HEADINGS_ROW);
      if existingColumnNames.values.length() == 0 {
          check spreadsheetClient->appendRowToSheet(spreadsheetId, worksheetName, columnNames);
      }

      (int|string|decimal)[] values = [payload.issue.html_url, issueNumber, issueTitle, payload.issue.user.login, payload.issue.created_at];
      check spreadsheetClient->appendRowToSheet(spreadsheetId, worksheetName, values);
      log:printInfo("New GiHub issue assignment record appended to GSheet successfully!");
    }
    remote function onClosed(github:IssuesEvent payload ) returns error? {
      //Not Implemented
    }
    remote function onReopened(github:IssuesEvent payload ) returns error? {
      //Not Implemented
    }
    remote function onAssigned(github:IssuesEvent payload ) returns error? {
      //Not Implemented
    }
    remote function onUnassigned(github:IssuesEvent payload ) returns error? {
      //Not Implemented
    }
    remote function onLabeled(github:IssuesEvent payload ) returns error? {
      //Not Implemented
    }
    remote function onUnlabeled(github:IssuesEvent payload ) returns error? {
      //Not Implemented
    }
}

service /ignore on httpListener {}
