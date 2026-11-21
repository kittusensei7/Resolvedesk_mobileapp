import 'package:flutter_test/flutter_test.dart';
import 'package:resolvedesk_mobileapp/services/permission_access.dart';

void main() {
  test('missing features and actions deny access', () {
    const access=PermissionAccess({});
    expect(access.can('service_calls'),false);
    expect(access.can('installations','edit'),false);
  });
  test('view does not enable writes', () {
    const access=PermissionAccess({'service_calls':{'view':true,'add':false}});
    expect(access.can('service_calls'),true);
    expect(access.can('service_calls','add'),false);
    expect(access.can('service_calls','delete'),false);
  });
  test('technician and sales response maps remain independent', () {
    const tech=PermissionAccess({'service_calls':{'view':true,'edit':true}});
    const sales=PermissionAccess({'service_calls':{'view':false,'edit':false}});
    expect(tech.can('service_calls','edit'),true);
    expect(sales.can('service_calls','edit'),false);
  });
  test('master Helpdesk response retains full access', () {
    const access=PermissionAccess({},isSuperadmin:true);
    expect(access.can('service_calls','delete'),true);
  });
}
