/* 
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 * 
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "ESPurpleJabberAccountViewController.h"
#import <Adium/AIService.h>
#import <Adium/AIContactList.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <tgmath.h>

#define SERVERFEEDRSSURL @"http://xmpp.org/services/services-full.xml"

@interface ESPurpleJabberAccountViewController ()
- (void)contactListChanged:(NSNotification *)n;
- (void)registrationSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
@end

@implementation ESPurpleJabberAccountViewController

- (NSString *)nibName{
    return @"ESPurpleJabberAccountView";
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	[checkBox_checkMail setEnabled:NO];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
								   selector:@selector(contactListChanged:)
									   name:Contact_ListChanged
									 object:nil];
}

//Configure our controls
- (void)configureForAccount:(AIAccount *)inAccount
{
    [super configureForAccount:inAccount];
	
	//Connection security
	[checkBox_forceOldSSL setState:[[account preferenceForKey:KEY_JABBER_FORCE_OLD_SSL group:GROUP_ACCOUNT_STATUS] boolValue]];
	[checkBox_requireTLS setState:[[account preferenceForKey:KEY_JABBER_REQUIRE_TLS group:GROUP_ACCOUNT_STATUS] boolValue]];
	[checkBox_checkCertificates setState:[account preferenceForKey:KEY_JABBER_VERIFY_CERTS group:GROUP_ACCOUNT_STATUS]?[[account preferenceForKey:KEY_JABBER_VERIFY_CERTS group:GROUP_ACCOUNT_STATUS] boolValue]:YES];
	[checkBox_allowPlaintext setState:[[account preferenceForKey:KEY_JABBER_ALLOW_PLAINTEXT group:GROUP_ACCOUNT_STATUS] boolValue]];
	
	//Resource
	NSString *resource = [account preferenceForKey:KEY_JABBER_RESOURCE group:GROUP_ACCOUNT_STATUS];
	if (!resource)
		resource = (__bridge_transfer NSString*)SCDynamicStoreCopyLocalHostName(NULL);
	if (!resource)
		resource = @"";	
	[textField_resource setStringValue:resource];
	
	//Connect server
	NSString *connectServer = [account preferenceForKey:KEY_JABBER_CONNECT_SERVER group:GROUP_ACCOUNT_STATUS];
	[textField_connectServer setStringValue:(connectServer ? connectServer : @"")];
	
	// BOSH server
	NSString *boshServer = [account preferenceForKey:KEY_JABBER_BOSH_SERVER group:GROUP_ACCOUNT_STATUS];
	[textField_BOSHserver setStringValue:(boshServer ?: @"")];	
	
	//Priority
	NSNumber *priority = [account preferenceForKey:KEY_JABBER_PRIORITY_AVAILABLE group:GROUP_ACCOUNT_STATUS];
	[textField_priorityAvailable setStringValue:(priority ? [priority stringValue] : @"")];
	priority = [account preferenceForKey:KEY_JABBER_PRIORITY_AWAY group:GROUP_ACCOUNT_STATUS];
	[textField_priorityAway setStringValue:(priority ? [priority stringValue] : @"")];
	
	//File transfer proxies
	NSString *ftProxies = [account preferenceForKey:KEY_JABBER_FT_PROXIES group:GROUP_ACCOUNT_STATUS];
	[textField_ftProxies setStringValue:ftProxies ?: @""];
		
	//Subscription behavior
	NSInteger subbeh = [[account preferenceForKey:KEY_JABBER_SUBSCRIPTION_BEHAVIOR group:GROUP_ACCOUNT_STATUS] integerValue];
	[popup_subscriptionBehavior selectItemWithTag:subbeh];
	NSString *defaultGroup = [account preferenceForKey:KEY_JABBER_SUBSCRIPTION_GROUP group:GROUP_ACCOUNT_STATUS];
	[comboBox_subscriptionGroup setStringValue:(defaultGroup ? defaultGroup : @"")];
	
	if (inAccount.UID.length > 0) {
		[checkBox_register setHidden:TRUE];
		[checkBox_register setState:NSOffState];
		[button_signUp setHidden:TRUE];
	}
	
	//Set hidden flag of the default group combobox
	[self subscriptionModeDidChange:nil];
}

//Save controls
- (void)saveConfiguration
{
    [super saveConfiguration];
	
	//Connection security
	[account setPreference:@([checkBox_forceOldSSL state])
					forKey:KEY_JABBER_FORCE_OLD_SSL group:GROUP_ACCOUNT_STATUS];
	[account setPreference:@([checkBox_requireTLS state])
					forKey:KEY_JABBER_REQUIRE_TLS group:GROUP_ACCOUNT_STATUS];
	[account setPreference:@([checkBox_checkCertificates state])
					forKey:KEY_JABBER_VERIFY_CERTS group:GROUP_ACCOUNT_STATUS];
	[account setPreference:@([checkBox_allowPlaintext state])
					forKey:KEY_JABBER_ALLOW_PLAINTEXT group:GROUP_ACCOUNT_STATUS];
	
	//Resource
	[account setPreference:([[textField_resource stringValue] length] ? [textField_resource stringValue] : nil)
					forKey:KEY_JABBER_RESOURCE group:GROUP_ACCOUNT_STATUS];
	
	//Connect server
	[account setPreference:([[textField_connectServer stringValue] length] ? [textField_connectServer stringValue] : nil)
					forKey:KEY_JABBER_CONNECT_SERVER group:GROUP_ACCOUNT_STATUS];
	
	//BOSH server
	[account setPreference:([[textField_BOSHserver stringValue] length] ? [textField_BOSHserver stringValue] : nil)
					forKey:KEY_JABBER_BOSH_SERVER group:GROUP_ACCOUNT_STATUS];	
	
	//FT proxies
	[account setPreference:[textField_ftProxies stringValue]
					forKey:KEY_JABBER_FT_PROXIES group:GROUP_ACCOUNT_STATUS];
	
	//Priority
	[account setPreference:([textField_priorityAvailable integerValue] ? @([textField_priorityAvailable integerValue]) : nil)
					forKey:KEY_JABBER_PRIORITY_AVAILABLE
					 group:GROUP_ACCOUNT_STATUS];
	[account setPreference:([textField_priorityAway integerValue] ? @([textField_priorityAway integerValue]) : nil)
					forKey:KEY_JABBER_PRIORITY_AWAY
					 group:GROUP_ACCOUNT_STATUS];

	//Subscription Behavior
	[account setPreference:([[popup_subscriptionBehavior selectedItem] tag] ? @([[popup_subscriptionBehavior selectedItem] tag]) : nil)
					forKey:KEY_JABBER_SUBSCRIPTION_BEHAVIOR
					 group:GROUP_ACCOUNT_STATUS];
	[account setPreference:([[comboBox_subscriptionGroup stringValue] length] ? [comboBox_subscriptionGroup stringValue] : nil)
					forKey:KEY_JABBER_SUBSCRIPTION_GROUP group:GROUP_ACCOUNT_STATUS];
	
	[account setPreference:@([checkBox_register state])
					forKey:KEY_ACCOUNT_REGISTER_ON_CONNECT
					 group:GROUP_ACCOUNT_STATUS];
}

- (IBAction)subscriptionModeDidChange:(id)sender {
	// only show these two when "accept and add to contact list" is selected
	NSInteger tag = [[popup_subscriptionBehavior selectedItem] tag];
	[textField_subscriptionModeLabel setHidden:tag != 2];
	[comboBox_subscriptionGroup setHidden:tag != 2];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark group combobox datasource

- (void)contactListChanged:(NSNotification*)n {
	[comboBox_subscriptionGroup reloadData];
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
	return [adium.contactController.contactList countOfContainedObjects];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)idx {
	return [[adium.contactController.contactList.containedObjects objectAtIndex:idx] formattedUID];
}

- (NSUInteger)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)string {
	NSArray *groups = adium.contactController.contactList.containedObjects;
	NSUInteger i;
	for(i = 0;i < [groups count];++i) {
		AIListGroup *group = [groups objectAtIndex:i];
		if([group.formattedUID isEqualToString:string])
			return i;
	}
	return NSNotFound;
}

- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)string {
	for(AIListObject *obj in adium.contactController.contactList) {
		if([obj isKindOfClass:[AIListGroup class]] && [obj.formattedUID hasPrefix:string])
			return obj.formattedUID;
	}
	return string;
}

#pragma mark account creation

- (IBAction)findServer:(id)sender {
	if(!servers) {
		NSURLRequest *serversRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:SERVERFEEDRSSURL]
														cachePolicy:NSURLRequestUseProtocolCachePolicy
													timeoutInterval:30];
		
		
		[NSURLConnection sendAsynchronousRequest:serversRequest
										   queue:[NSOperationQueue mainQueue]
							   completionHandler:^(NSURLResponse *response, NSData *serverfeedData, NSError *err) {
								   
								   if(err) {
									   [[NSAlert alertWithError:err] runModal];
									   return;
								   }
								   
								   NSXMLDocument *serverfeed = [[NSXMLDocument alloc] initWithData:serverfeedData
																						   options:0
																							 error:&err];
								   if (err) {
									   [[NSAlert alertWithError:err] runModal];
									   return;
								   }
								   
								   NSXMLElement *root = [serverfeed rootElement];
								   NSArray *items = [root elementsForName:@"item"];
								   
								   if(!root || !items || ![[root name] isEqualToString:@"query"]) {
									   [[NSAlert alertWithMessageText:AILocalizedString(@"Parse Error.",nil)
														defaultButton:AILocalizedString(@"OK",nil)
													  alternateButton:nil
														  otherButton:nil
											informativeTextWithFormat:AILocalizedString(@"Unable to parse the server list at %@. Please try again later.",nil), SERVERFEEDRSSURL] runModal];
								   } else {
									   MachineLocation loc;
									   
									   ReadLocation(&loc);
									   
									   CGFloat latitude = (CGFloat)(FractToFloat(loc.latitude)*(M_PI/2.0));
									   CGFloat longitude = (CGFloat)(FractToFloat(loc.longitude)*(M_PI/2.0));
									   
									   servers = [[NSMutableArray alloc] init];
									   
									   for (NSXMLElement *item in items) {
										   NSXMLElement *title = [[item elementsForName:@"domain"] lastObject];
										   if(!title)
											   continue;
										   NSXMLElement *description = [[item elementsForName:@"description"] lastObject];
										   NSXMLElement *latitudeNode  = [[item elementsForName:@"latitude"] lastObject];
										   NSXMLElement *longitudeNode = [[item elementsForName:@"longitude"] lastObject];
										   NSString *domain = [[item attributeForName:@"jid"] stringValue];
										   NSString *homepageStr = [[[item elementsForName:@"homepage"] lastObject] stringValue];
										   NSURL *homepage = homepageStr?[NSURL URLWithString:homepageStr]:nil;
										   
										   id distance = [NSNull null];
										   if (latitudeNode && longitudeNode) {
											   /* Calculate the distance between the computer and the xmpp server in km
												* Note that this assumes that the earth is a perfect sphere
												* If it turns out to be flat or doughnut-shaped, this will not work!
												*/
											   
											   CGFloat latitude2 = (CGFloat)([[latitudeNode stringValue] doubleValue] * (M_PI/180.0));
											   CGFloat longitude2 = (CGFloat)([[longitudeNode stringValue] doubleValue] * (M_PI/180.0));
											   
											   CGFloat d_lat = AIsin((latitude2 - latitude)/2.0f);
											   CGFloat d_long = AIsin((longitude2 - longitude)/2.0f);
											   CGFloat a = d_lat*d_lat + AIcos(latitude)*AIcos(latitude2)*d_long*d_long;
											   CGFloat c = 2*AIatan2(AIsqrt(a),AIsqrt(1.0f-a));
											   CGFloat d = 6372.797f*c; // mean earth radius
											   
											   distance = @(d);
										   }
										   
										   [(NSMutableArray*)servers addObject:
											@{ @"servername" : [title stringValue],
											@"description" : (description ? (id)[description stringValue] : (id)[NSNull null]),
											@"distance" : distance,
											@"domain" : domain,
											@"homepage" : (homepage ?: (id)[NSNull null]) }];
									   }
									   
									   [(NSMutableArray*)servers sortUsingComparator:^NSComparisonResult(id one, id two) {
										   NSNumber *dist1obj = [one objectForKey:@"distance"];
										   NSNumber *dist2obj = [two objectForKey:@"distance"];
										   
										   if((id)dist2obj == [NSNull null]) {
											   if((id)dist1obj == [NSNull null])
												   return NSOrderedSame;
											   return NSOrderedAscending;
										   }
										   if((id)dist1obj == [NSNull null])
											   return NSOrderedDescending;
										   
										   CGFloat dist1 = (CGFloat)[dist1obj doubleValue];
										   CGFloat dist2 = (CGFloat)[dist2obj doubleValue];
										   
										   if(fabs(dist1 - dist2) < 0.000001)
											   return NSOrderedSame;
										   
										   if(dist1 > dist2)
											   return NSOrderedDescending;
										   return NSOrderedAscending;
									   }];
									   
									   [tableview_servers reloadData];
								   }
							   }];
	}
	
	[NSApp beginSheet:window_registerServer
	   modalForWindow:[sender window]
		modalDelegate:self
	   didEndSelector:@selector(registrationSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}

- (void)registrationSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [servers count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	id objectValue = [[servers objectAtIndex:row] objectForKey:[tableColumn identifier]];
	return ((objectValue && ![objectValue isKindOfClass:[NSNull class]]) ? objectValue : @"");
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	NSDictionary *serverInfo = [servers objectAtIndex:[tableview_servers selectedRow]];

	[textView_serverDescription setString:[serverInfo objectForKey:@"description"]];
	
	[button_serverHomepage setEnabled:[serverInfo objectForKey:@"homepage"] != [NSNull null]];
}

- (IBAction)visitServerHomepage:(id)sender {
	NSDictionary *serverInfo = [servers objectAtIndex:[tableview_servers selectedRow]];
	
	[[NSWorkspace sharedWorkspace] openURL:[serverInfo objectForKey:@"homepage"]];
}

- (IBAction)findServerCancel:(id)sender {
	[window_registerServer orderOut:nil];
	[NSApp endSheet:window_registerServer];
}

- (IBAction)findServerAccept:(id)sender {
	NSDictionary *serverInfo = [servers objectAtIndex:[tableview_servers selectedRow]];
	
	[[sender window] makeFirstResponder:nil]; // apply all changes
	
	[window_registerServer orderOut:nil];
	[NSApp endSheet:window_registerServer];
	
	[account setPreference:@(5222)
					forKey:KEY_CONNECT_PORT
					 group:GROUP_ACCOUNT_STATUS];
	
	NSString *newUID;
	
	if ([[textField_accountUID stringValue] length]) {
		NSRange atLocation = [[textField_accountUID stringValue] rangeOfString:@"@" options:NSLiteralSearch];
		if (atLocation.location == NSNotFound)
			newUID = [NSString stringWithFormat:@"%@@%@", [textField_accountUID stringValue],
					  [serverInfo objectForKey:@"domain"]];
		else
			newUID = [NSString stringWithFormat:@"%@@%@", [[textField_accountUID stringValue] substringToIndex:atLocation.location],
					  [serverInfo objectForKey:@"domain"]];
		
		[account filterAndSetUID:newUID];
		[textField_accountUID setStringValue:account.UID];
	} else {
		NSString *nobody = AILocalizedString(@"nobody", nil);
		newUID = [NSString stringWithFormat:@"%@@%@", nobody, [serverInfo objectForKey:@"domain"]];
		
		[account filterAndSetUID:newUID];
		[textField_accountUID setStringValue:account.UID];
		[textField_accountUID selectText:self];
		NSText *fieldEditor = [textField_accountUID.window fieldEditor:YES forObject:textField_accountUID];
		[fieldEditor setSelectedRange:NSMakeRange(0, [nobody length])];
	}
	
	[checkBox_register setState:NSOnState];
}

@end
