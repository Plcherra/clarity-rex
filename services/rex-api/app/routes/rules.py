from typing import Optional, Union

from fastapi import APIRouter, Depends, Query, Response

from app.dependencies import get_rule_service
from app.models.pagination import PagedResponse
from app.models.personal_rule import (
    PersonalRuleCreateRequest,
    PersonalRuleResponse,
    PersonalRuleUpdateRequest,
    RuleStatus,
    RuleType,
)
from app.routes.list_pagination import list_with_optional_pagination
from app.services.rule_service import RuleService, RuleServiceError


router = APIRouter(prefix="/rules", tags=["rules"])


@router.get("")
async def list_rules(
    rule_type: Optional[RuleType] = Query(default=None),
    status: Optional[RuleStatus] = Query(default=None),
    active: Optional[bool] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    paginated: bool = Query(default=False),
    cursor: Optional[str] = Query(default=None),
    rule_service: RuleService = Depends(get_rule_service),
) -> Union[list[PersonalRuleResponse], PagedResponse[PersonalRuleResponse]]:
    try:
        return await list_with_optional_pagination(
            paginated=paginated,
            cursor=cursor,
            limit=limit,
            list_items=lambda **kwargs: rule_service.list_rules(
                rule_type=rule_type,
                status=status,
                active=active,
                **kwargs,
            ),
            list_paged=lambda **kwargs: rule_service.list_rules_paged(
                rule_type=rule_type,
                status=status,
                active=active,
                **kwargs,
            ),
            to_response=lambda row: PersonalRuleResponse(**row),
        )
    except RuleServiceError as error:
        raise _rule_http_error(error) from error


@router.post("", response_model=PersonalRuleResponse, status_code=201)
async def create_rule(
    request: PersonalRuleCreateRequest,
    rule_service: RuleService = Depends(get_rule_service),
) -> PersonalRuleResponse:
    try:
        rule = await rule_service.create_rule(request)
    except RuleServiceError as error:
        raise _rule_http_error(error) from error

    return PersonalRuleResponse(**rule)


@router.patch("/{rule_id}", response_model=PersonalRuleResponse)
async def update_rule(
    rule_id: str,
    request: PersonalRuleUpdateRequest,
    rule_service: RuleService = Depends(get_rule_service),
) -> PersonalRuleResponse:
    try:
        rule = await rule_service.update_rule(rule_id, request)
    except RuleServiceError as error:
        raise _rule_http_error(error) from error

    return PersonalRuleResponse(**rule)


@router.delete("/{rule_id}", status_code=204)
async def deactivate_rule(
    rule_id: str,
    rule_service: RuleService = Depends(get_rule_service),
) -> Response:
    try:
        await rule_service.deactivate_rule(rule_id)
    except RuleServiceError as error:
        raise _rule_http_error(error) from error

    return Response(status_code=204)


def _rule_http_error(error: RuleServiceError):
    from fastapi import HTTPException

    return HTTPException(status_code=error.status_code, detail=error.detail)
