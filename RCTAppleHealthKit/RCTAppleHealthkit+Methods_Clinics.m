//
//  RCTAppleHealthkit+Methods_Clinics.m
//  RCTAppleHealthKit
//
//  Created by Yair Pinchasi on 21/08/2025.
//  Copyright © 2025 Greg Wilson. All rights reserved.
//

#import "RCTAppleHealthkit+Methods_Clinics.h"
#import "RCTAppleHealthKit+Queries.h"
#import "RCTAppleHealthKit+Utils.h"

// Maps LOINC codes to CholesterolPanel field names.
static NSString * _cholesterolFieldForLoinc(NSString *code) {
    if (!code) return nil;
    static NSDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"2093-3":  @"total",
            @"2089-1":  @"ldl",
            @"18262-6": @"ldl",
            @"13457-7": @"ldl",
            @"2085-9":  @"hdl",
            @"2571-8":  @"triglycerides",
        };
    });
    return map[code];
}

// Groups raw FHIR LabResultRecord records into cholesterol panels.
// Panels without a `total` value are excluded.
// Returns unsorted array — caller is responsible for ordering.
static NSArray * _buildCholesterolPanels(NSArray *records) {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];

    for (NSDictionary *record in records) {
        id fhirData = record[@"fhirData"];
        if (![fhirData isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *fhir = (NSDictionary *)fhirData;
        if (![@"Observation" isEqualToString:fhir[@"resourceType"]]) continue;

        NSString *loincCode = nil;
        NSArray *codings = [fhir[@"code"] objectForKey:@"coding"];
        for (NSDictionary *coding in codings) {
            if ([@"http://loinc.org" isEqualToString:coding[@"system"]]) {
                loincCode = coding[@"code"];
                break;
            }
        }

        NSString *field = _cholesterolFieldForLoinc(loincCode);
        if (!field) continue;

        NSDictionary *valueQuantity = fhir[@"valueQuantity"];
        NSNumber *value = valueQuantity[@"value"];
        if (!value) continue;

        NSString *sourceId  = record[@"sourceId"]  ?: @"";
        NSString *startDate = record[@"startDate"] ?: @"";
        NSString *dayKey    = startDate.length >= 10 ? [startDate substringToIndex:10] : startDate;
        NSString *groupKey  = [NSString stringWithFormat:@"%@|%@", sourceId, dayKey];

        NSMutableDictionary *panel = groups[groupKey];
        if (!panel) {
            panel = [@{
                @"startDate":  startDate,
                @"endDate":    record[@"endDate"]    ?: @"",
                @"sourceName": record[@"sourceName"] ?: @"",
                @"sourceId":   sourceId,
            } mutableCopy];
            groups[groupKey] = panel;
        }
        panel[field] = value;
    }

    NSMutableArray *panels = [NSMutableArray array];
    for (NSDictionary *panel in groups.allValues) {
        if (panel[@"total"]) {
            [panels addObject:panel];
        }
    }
    return panels;
}

@implementation RCTAppleHealthKit (Methods_Clinics)

- (void)clinics_getMedications:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    [self fetchClinicalRecordsOfType:[HKClinicalType clinicalTypeForIdentifier:HKClinicalTypeIdentifierMedicationRecord]
                 predicate:nil
                 ascending:false
                     limit:HKObjectQueryNoLimit
                          completion:^(NSArray *results, NSError *error) {
                              if(results){
                                  callback(@[[NSNull null], results]);
                                  return;
                              } else {
                                  NSLog(@"error getting medications: %@", error);
                                  callback(@[RCTMakeError(@"error getting medications", nil, nil)]);
                                  return;
                              }
                          }];
}

- (void)clinics_getConditions:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    [self fetchClinicalRecordsOfType:[HKClinicalType clinicalTypeForIdentifier:HKClinicalTypeIdentifierConditionRecord]
               predicate:nil
               ascending:false
                   limit:HKObjectQueryNoLimit
                          completion:^(NSArray *results, NSError *error) {
                              if(results){
                                  callback(@[[NSNull null], results]);
                                  return;
                              } else {
                                  NSLog(@"error getting conditions: %@", error);
                                  callback(@[RCTMakeError(@"error getting conditions", nil, nil)]);
                                  return;
                              }
                          }];
}

- (void)clinics_getAllergyRecords:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    [self fetchClinicalRecordsOfType:[HKClinicalType clinicalTypeForIdentifier:HKClinicalTypeIdentifierAllergyRecord]
               predicate:nil
               ascending:false
                   limit:HKObjectQueryNoLimit
                          completion:^(NSArray *results, NSError *error) {
                              if(results){
                                  callback(@[[NSNull null], results]);
                                  return;
                              } else {
                                  NSLog(@"error getting allergies: %@", error);
                                  callback(@[RCTMakeError(@"error getting allergies", nil, nil)]);
                                  return;
                              }
                          }];
}

- (void)clinics_getImmunizationRecords:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    [self fetchClinicalRecordsOfType:[HKClinicalType clinicalTypeForIdentifier:HKClinicalTypeIdentifierImmunizationRecord]
               predicate:nil
               ascending:false
                   limit:HKObjectQueryNoLimit
                          completion:^(NSArray *results, NSError *error) {
                              if(results){
                                  callback(@[[NSNull null], results]);
                                  return;
                              } else {
                                  NSLog(@"error getting immunizations: %@", error);
                                  callback(@[RCTMakeError(@"error getting immunizations", nil, nil)]);
                                  return;
                              }
                          }];
}

- (void)clinics_getProcedureRecords:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    [self fetchClinicalRecordsOfType:[HKClinicalType clinicalTypeForIdentifier:HKClinicalTypeIdentifierProcedureRecord]
               predicate:nil
               ascending:false
                   limit:HKObjectQueryNoLimit
                          completion:^(NSArray *results, NSError *error) {
                              if(results){
                                  callback(@[[NSNull null], results]);
                                  return;
                              } else {
                                  NSLog(@"error getting procedures: %@", error);
                                  callback(@[RCTMakeError(@"error getting procedures", nil, nil)]);
                                  return;
                              }
                          }];
}

- (void)clinics_getLabRecords:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    [self fetchClinicalRecordsOfType:[HKClinicalType clinicalTypeForIdentifier:HKClinicalTypeIdentifierLabResultRecord]
                    predicate:nil
                    ascending:false
                        limit:HKObjectQueryNoLimit
                          completion:^(NSArray *results, NSError *error) {
                              if(results){
                                  callback(@[[NSNull null], results]);
                                  return;
                              } else {
                                  NSLog(@"error getting lab records: %@", error);
                                  callback(@[RCTMakeError(@"error getting lab records", nil, nil)]);
                                  return;
                              }
                          }];
}

- (void)clinics_getClinicalVitalsRecords:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    [self fetchClinicalRecordsOfType:[HKClinicalType clinicalTypeForIdentifier:HKClinicalTypeIdentifierVitalSignRecord]
               predicate:nil
               ascending:false
                   limit:HKObjectQueryNoLimit
                          completion:^(NSArray *results, NSError *error) {
                              if(results){
                                  callback(@[[NSNull null], results]);
                                  return;
                              } else {
                                  NSLog(@"error getting clinical vitals: %@", error);
                                  callback(@[RCTMakeError(@"error getting clinical vitals", nil, nil)]);
                                  return;
                              }
                          }];
}

+ (NSDictionary *)cholesterolFieldFromFHIRRecord:(NSDictionary *)record {
    id fhirData = record[@"fhirData"];
    if (![fhirData isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *fhir = (NSDictionary *)fhirData;
    if (![@"Observation" isEqualToString:fhir[@"resourceType"]]) return nil;

    NSString *loincCode = nil;
    NSArray *codings = [fhir[@"code"] objectForKey:@"coding"];
    for (NSDictionary *coding in codings) {
        if ([@"http://loinc.org" isEqualToString:coding[@"system"]]) {
            loincCode = coding[@"code"];
            break;
        }
    }

    NSString *field = _cholesterolFieldForLoinc(loincCode);
    if (!field) return nil;

    NSDictionary *valueQuantity = fhir[@"valueQuantity"];
    NSNumber *value = valueQuantity[@"value"];
    if (!value) return nil;

    return @{ @"field": field, @"value": value };
}

- (void)clinics_getCholesterolReadings:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback {
    if (@available(iOS 12.0, *)) {
        HKClinicalType *labType = (HKClinicalType *)[RCTAppleHealthKit clinicalTypeFromName:@"LabResultRecord"];
        if (labType == nil) {
            callback(@[RCTMakeError(@"Clinical records entitlement not available", nil, nil)]);
            return;
        }

        NSDate *startDate = [RCTAppleHealthKit dateFromOptions:input key:@"startDate" withDefault:nil];
        if (startDate == nil) {
            callback(@[RCTMakeError(@"startDate is required in options", nil, nil)]);
            return;
        }
        NSDate *endDate  = [RCTAppleHealthKit dateFromOptions:input key:@"endDate"   withDefault:[NSDate date]];
        NSUInteger limit = [RCTAppleHealthKit uintFromOptions:input key:@"limit"     withDefault:HKObjectQueryNoLimit];
        BOOL ascending   = [RCTAppleHealthKit boolFromOptions:input key:@"ascending" withDefault:false];

        NSPredicate *predicate = [RCTAppleHealthKit predicateForSamplesBetweenDates:startDate endDate:endDate];

        // Fetch all lab records in range — grouping reduces count, so limit is applied after.
        [self fetchClinicalRecordsOfType:labType
                               predicate:predicate
                               ascending:false
                                   limit:HKObjectQueryNoLimit
                              completion:^(NSArray *results, NSError *error) {
            if (!results) {
                callback(@[RCTJSErrorFromNSError(error)]);
                return;
            }
            NSArray *panels = _buildCholesterolPanels(results);
            NSArray *sorted = [panels sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                return ascending
                    ? [a[@"startDate"] compare:b[@"startDate"]]
                    : [b[@"startDate"] compare:a[@"startDate"]];
            }];
            if (limit != HKObjectQueryNoLimit && sorted.count > limit) {
                sorted = [sorted subarrayWithRange:NSMakeRange(0, limit)];
            }
            callback(@[[NSNull null], sorted]);
        }];
    } else {
        callback(@[RCTMakeError(@"cholesterolReadings requires iOS 12.0 or later", nil, nil)]);
    }
}

@end
