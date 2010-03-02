/* Copyright (c) 2007 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  GDataServiceGoogleDocs.m
//

#if !GDATA_REQUIRE_SERVICE_INCLUDES || GDATA_INCLUDE_DOCS_SERVICE

#define GDATASERVICEDOCS_DEFINE_GLOBALS 1
#import "GDataServiceGoogleDocs.h"
#import "GDataDocConstants.h"
#import "GDataEntryDocBase.h"
#import "GDataQueryDocs.h"
#import "GDataFeedDocList.h"
#import "GDataFeedDocRevision.h"


@implementation GDataServiceGoogleDocs

+ (NSURL *)docsFeedURLUsingHTTPS:(BOOL)shouldUseHTTPS {
  NSURL *url = [self docsURLForUserID:kGDataServiceDefaultUser
                           visibility:kGDataGoogleDocsVisibilityPrivate
                           projection:kGDataGoogleDocsProjectionFull
                           resourceID:nil
                             feedType:nil
                           revisionID:nil
                             useHTTPS:shouldUseHTTPS];
  return url;
}

+ (NSURL *)folderContentsFeedURLForFolderID:(NSString *)resourceID
                                   useHTTPS:(BOOL)shouldUseHTTPS {
  NSURL *url = [self docsURLForUserID:kGDataServiceDefaultUser
                           visibility:kGDataGoogleDocsVisibilityPrivate
                           projection:kGDataGoogleDocsProjectionFull
                           resourceID:resourceID
                             feedType:kGDataGoogleDocsFeedTypeFolderContents
                           revisionID:nil
                             useHTTPS:shouldUseHTTPS];
  return url;
}

+ (NSURL *)docsURLForUserID:(NSString *)userID
                 visibility:(NSString *)visibility
                 projection:(NSString *)projection
                 resourceID:(NSString *)resourceID
                   feedType:(NSString *)feedType
                 revisionID:(NSString *)revisionID
                   useHTTPS:(BOOL)shouldUseHTTPS {
  // get the root URL, and fix the scheme
  NSString *rootURLStr = [self serviceRootURLString];
  if (!shouldUseHTTPS) {
    rootURLStr = [NSString stringWithFormat:@"http:%@",
                  [rootURLStr substringFromIndex:6]];
  }

  if (projection == nil) {
    projection = @"full";
  }

  NSString *template = @"%@%@/%@/%@";
  NSString *encodedUser = [GDataUtilities stringByURLEncodingForURI:userID];
  NSString *urlStr = [NSString stringWithFormat:template,
                      rootURLStr, encodedUser, visibility, projection];

  // now add the optional parts
  if (resourceID) {
    NSString *encodedResID = [GDataUtilities stringByURLEncodingForURI:resourceID];
    urlStr = [urlStr stringByAppendingFormat:@"/%@", encodedResID];
  }

  if (feedType) {
    urlStr = [urlStr stringByAppendingFormat:@"/%@", feedType];
  }

  if (revisionID) {
    urlStr = [urlStr stringByAppendingFormat:@"/%@", revisionID];
  }

  return [NSURL URLWithString:urlStr];
}

+ (NSURL *)docsUploadURL {
  NSString *const kPath = @"upload/create-session/default/private/full";
  NSString *root = [self serviceRootURLString];
  NSString *urlString = [root stringByAppendingString:kPath];

  return [NSURL URLWithString:urlString];
}

+ (NSURL *)metadataEntryURLForUserID:(NSString *)userID {
  NSString *encodedUser = [GDataUtilities stringByURLEncodingForURI:userID];
  NSString *const kTemplate = @"%@metadata/%@";

  NSString *root = [self serviceRootURLString];
  NSString *urlString = [NSString stringWithFormat:kTemplate,
                         root, encodedUser];

  return [NSURL URLWithString:urlString];
}

#pragma mark -

// updating a document entry with data requires the editMediaLink rather than
// the editLink, per
//
// http://code.google.com/apis/documents/docs/3.0/developers_guide_protocol.html#UpdatingContent

- (GDataServiceTicket *)fetchEntryByUpdatingEntry:(GDataEntryBase *)entryToUpdate
                                         delegate:(id)delegate
                                didFinishSelector:(SEL)finishedSelector {
  GDataLink *link;

  // temporary: use override header for chunked updates (bug 2433537)
  BOOL wasUsingOverride = [self shouldUseMethodOverrideHeader];

  if ([entryToUpdate uploadData] == nil || [self serviceUploadChunkSize] == 0) {
    // not uploading document data, or else doing a multipart MIME upload
    link = [entryToUpdate editLink];
  } else {
    // doing a chunked upload
    link = [entryToUpdate uploadEditLink];

    // temporary; see above
    [self setShouldUseMethodOverrideHeader:YES];
  }

  NSURL *editURL = [link URL];

  GDataServiceTicket *ticket = [self fetchEntryByUpdatingEntry:entryToUpdate
                                                   forEntryURL:editURL
                                                      delegate:delegate
                                             didFinishSelector:finishedSelector];

  // temporary; see above
  [self setShouldUseMethodOverrideHeader:wasUsingOverride];
  return ticket;
}

#pragma mark -

+ (NSString *)serviceRootURLString {
  return @"https://docs.google.com/feeds/";
}

+ (NSString *)serviceID {
  return @"writely";
}

+ (NSString *)defaultServiceVersion {
  return kGDataDocsDefaultServiceVersion;
}

+ (NSUInteger)defaultServiceUploadChunkSize {
  return kGDataStandardUploadChunkSize;
}

+ (NSDictionary *)standardServiceNamespaces {
  return [GDataDocConstants baseDocumentNamespaces];
}

@end

#endif // !GDATA_REQUIRE_SERVICE_INCLUDES || GDATA_INCLUDE_DOCS_SERVICE
