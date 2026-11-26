import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import {
  Public,
  RequirePermission,
} from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import {
  CreateGroupServiceDto,
  JoinGroupServiceDto,
  QuoteGroupServiceDto,
  SelectGroupQuoteDto,
  UpdateGroupServiceStatusDto,
} from './group-services.dto';
import { GroupServicesService } from './group-services.service';

const groupId = new ParseUUIDPipe({ version: '4' });
const memberIdPipe = new ParseUUIDPipe({ version: '4' });

// URL fragments stay in the browser, keeping invitation credentials out of request logs.
const inviteScript = `
  const token = location.hash.slice(1);
  if (/^[a-f0-9]{48}$/.test(token)) {
    const link = document.getElementById('open-fixnow');
    link.href = 'fixnow://group-invite/' + token;
    link.hidden = false;
  } else {
    document.getElementById('invalid-invite').hidden = false;
  }
`;
const inviteScriptHash = createHash('sha256')
  .update(inviteScript)
  .digest('base64');

@Controller('group-services')
export class GroupServicesController {
  constructor(private readonly groups: GroupServicesService) {}

  @Get('invite')
  @Public()
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  @Header('Referrer-Policy', 'no-referrer')
  @Header(
    'Content-Security-Policy',
    `default-src 'none'; script-src 'sha256-${inviteScriptHash}'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'`,
  )
  invite() {
    return `<!doctype html><html lang="en"><meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Join a FixNow service group</title>
      <main><h1>Join a FixNow service group</h1>
      <p><a id="open-fixnow" hidden>Open FixNow to join</a></p>
      <p id="invalid-invite" hidden>This invitation link is incomplete.</p>
      <p>If the app does not open, paste this invitation link into Group services in FixNow.</p>
      </main><script>${inviteScript}</script></html>`;
  }

  @Get('categories')
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  categories() {
    return this.groups.categories();
  }

  @Get()
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  list(@Req() req: AuthorizedRequest) {
    return this.groups.listCustomer(req.authorizationPrincipal!.userId);
  }

  @Get('provider')
  @Header('Cache-Control', 'no-store')
  @RequirePermission(PERMISSIONS.groupServiceProvider)
  provider(@Req() req: AuthorizedRequest) {
    return this.groups.listProvider(req.authorizationPrincipal!.userId);
  }

  @Post()
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  create(@Req() req: AuthorizedRequest, @Body() dto: CreateGroupServiceDto) {
    return this.groups.create(req.authorizationPrincipal!.userId, dto);
  }

  @Post('join')
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  join(@Req() req: AuthorizedRequest, @Body() dto: JoinGroupServiceDto) {
    return this.groups.join(
      req.authorizationPrincipal!.userId,
      dto.token,
      dto.serviceAddress,
    );
  }

  @Get(':id')
  @Header('Cache-Control', 'no-store')
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  detail(@Req() req: AuthorizedRequest, @Param('id', groupId) id: string) {
    return this.groups.detail(req.authorizationPrincipal!.userId, id);
  }

  @Post(':id/members/:memberId/approve')
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  approveMember(
    @Req() req: AuthorizedRequest,
    @Param('id', groupId) id: string,
    @Param('memberId', memberIdPipe) memberId: string,
  ) {
    return this.groups.approveMember(
      req.authorizationPrincipal!.userId,
      id,
      memberId,
    );
  }

  @Post(':id/members/:memberId/reject')
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  rejectMember(
    @Req() req: AuthorizedRequest,
    @Param('id', groupId) id: string,
    @Param('memberId', memberIdPipe) memberId: string,
  ) {
    return this.groups.rejectMember(
      req.authorizationPrincipal!.userId,
      id,
      memberId,
    );
  }

  @Post(':id/request')
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  request(@Req() req: AuthorizedRequest, @Param('id', groupId) id: string) {
    return this.groups.request(req.authorizationPrincipal!.userId, id);
  }

  @Post(':id/quotes')
  @RequirePermission(PERMISSIONS.groupServiceProvider)
  quote(
    @Req() req: AuthorizedRequest,
    @Param('id', groupId) id: string,
    @Body() dto: QuoteGroupServiceDto,
  ) {
    return this.groups.quote(req.authorizationPrincipal!.userId, id, dto);
  }

  @Post(':id/select')
  @RequirePermission(PERMISSIONS.groupServiceCustomer)
  select(
    @Req() req: AuthorizedRequest,
    @Param('id', groupId) id: string,
    @Body() dto: SelectGroupQuoteDto,
  ) {
    return this.groups.select(
      req.authorizationPrincipal!.userId,
      id,
      dto.quoteId,
    );
  }

  @Post(':id/status')
  @RequirePermission(PERMISSIONS.groupServiceProvider)
  updateStatus(
    @Req() req: AuthorizedRequest,
    @Param('id', groupId) id: string,
    @Body() dto: UpdateGroupServiceStatusDto,
  ) {
    return this.groups.updateStatus(
      req.authorizationPrincipal!.userId,
      id,
      dto.status,
    );
  }
}
