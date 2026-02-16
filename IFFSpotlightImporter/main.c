#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include <stdio.h>

// Forward declaration — implemented in Swift via @_cdecl
extern Boolean GetMetadataForFile(void *thisInterface,
                                   CFMutableDictionaryRef attributes,
                                   CFStringRef contentTypeUTI,
                                   CFStringRef pathToFile);

// Plugin instance
typedef struct {
    MDImporterInterfaceStruct *vtable;
    CFUUIDRef factoryID;
    UInt32 refCount;
} MDImporterPluginType;

// Forward declarations
static MDImporterPluginType *AllocPlugin(CFUUIDRef factoryID);
static void DeallocPlugin(MDImporterPluginType *instance);
static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv);
static ULONG PluginAddRef(void *thisInstance);
static ULONG PluginRelease(void *thisInstance);
static Boolean ImporterImportData(void *thisInstance,
                                   CFMutableDictionaryRef attributes,
                                   CFStringRef contentTypeUTI,
                                   CFStringRef pathToFile);

// Single static vtable
static MDImporterInterfaceStruct gVTable = {
    NULL,
    QueryInterface,
    PluginAddRef,
    PluginRelease,
    ImporterImportData
};

static MDImporterPluginType *AllocPlugin(CFUUIDRef factoryID) {
    MDImporterPluginType *instance = (MDImporterPluginType *)malloc(sizeof(MDImporterPluginType));
    instance->vtable = &gVTable;
    instance->factoryID = CFRetain(factoryID);
    instance->refCount = 1;
    CFPlugInAddInstanceForFactory(factoryID);
    return instance;
}

static void DeallocPlugin(MDImporterPluginType *instance) {
    CFUUIDRef factoryID = instance->factoryID;
    free(instance);
    if (factoryID) {
        CFPlugInRemoveInstanceForFactory(factoryID);
        CFRelease(factoryID);
    }
}

static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv) {
    CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);

    if (CFEqual(interfaceID, kMDImporterInterfaceID) ||
        CFEqual(interfaceID, IUnknownUUID)) {
        ((MDImporterPluginType *)thisInstance)->vtable = &gVTable;
        PluginAddRef(thisInstance);
        *ppv = thisInstance;
        CFRelease(interfaceID);
        return S_OK;
    }

    *ppv = NULL;
    CFRelease(interfaceID);
    return E_NOINTERFACE;
}

static ULONG PluginAddRef(void *thisInstance) {
    return ++((MDImporterPluginType *)thisInstance)->refCount;
}

static ULONG PluginRelease(void *thisInstance) {
    MDImporterPluginType *instance = (MDImporterPluginType *)thisInstance;
    instance->refCount--;
    if (instance->refCount == 0) {
        DeallocPlugin(instance);
        return 0;
    }
    return instance->refCount;
}

static Boolean ImporterImportData(void *thisInstance,
                                   CFMutableDictionaryRef attributes,
                                   CFStringRef contentTypeUTI,
                                   CFStringRef pathToFile) {
    return GetMetadataForFile(thisInstance,
                              attributes,
                              contentTypeUTI,
                              pathToFile);
}

// Factory function — name must match CFPlugInFactories in Info.plist
void *MetadataImporterPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeID) {
    if (CFEqual(typeID, kMDImporterTypeID)) {
        CFUUIDRef factoryID = CFUUIDCreateFromString(kCFAllocatorDefault,
            CFSTR("9AA4D26D-7C0E-4635-B941-E8F367BC4D0E"));
        MDImporterPluginType *result = AllocPlugin(factoryID);
        CFRelease(factoryID);
        return result;
    }
    return NULL;
}
