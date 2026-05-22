const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const features = @import("features/mod.zig");

pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

const dashboard = features.dashboard.index;
const workspaces = features.workspaces.workspaces;
const graphifyIndex = features.graphify.index;
const workspaceNew = features.workspaces.workspaceNew;
const workspaceCreate = features.workspaces.workspaceCreate;
const workspaceEdit = features.workspaces.workspaceEdit;
const workspaceUpdate = features.workspaces.workspaceUpdate;
const workspaceConfirmLocalPathChange = features.workspaces.workspaceConfirmLocalPathChange;
const workspaceDelete = features.workspaces.workspaceDelete;
const workspaceGraphifyShow = features.graphify.workspaceShow;
const workspaceMemoryCreate = features.workspaces.workspaceMemoryCreate;
const workspaceMemoryUpdate = features.workspaces.workspaceMemoryUpdate;
const workspaceMemoryDelete = features.workspaces.workspaceMemoryDelete;
const workspaceHandoffCreate = features.workspaces.workspaceHandoffCreate;
const workspaceHandoffUpdate = features.workspaces.workspaceHandoffUpdate;
const workspaceHandoffDelete = features.workspaces.workspaceHandoffDelete;
const workspaceDecisionRecordCreate = features.workspaces.workspaceDecisionRecordCreate;
const workspaceDecisionRecordUpdate = features.workspaces.workspaceDecisionRecordUpdate;
const workspaceDecisionRecordDelete = features.workspaces.workspaceDecisionRecordDelete;
const workspaceSnapshotCreate = features.workspaces.workspaceSnapshotCreate;
const workspaceSnapshotUpdate = features.workspaces.workspaceSnapshotUpdate;
const workspaceSnapshotDelete = features.workspaces.workspaceSnapshotDelete;
const workspaceRuntimePrepare = features.workspaces.workspaceRuntimePrepare;
const workspaceRuntimeStart = features.workspaces.workspaceRuntimeStart;
const workspaceRuntimeStop = features.workspaces.workspaceRuntimeStop;
const workspaceRuntimeLiveStatus = features.workspaces.workspaceRuntimeLiveStatus;
const workspacePaneOpenSession = features.workspaces.workspacePaneOpenSession;
const workspacePaneCloseSession = features.workspaces.workspacePaneCloseSession;
const workspacePaneResumeSession = features.workspaces.workspacePaneResumeSession;
const workspacePaneRecreateSession = features.workspaces.workspacePaneRecreateSession;
const workspaceShow = features.workspaces.workspaceShow;
const workspaceMissionActivate = features.missions_dispatch.activate;

const workspaceMissionDispatchToPilot = features.missions_dispatch.dispatchToPilot;
const workspaceMissionDispatchPilotBriefToPlanner = features.missions_dispatch.dispatchPilotBriefToPlanner;
const workspaceMissionDispatchPlannerPlanToScout = features.missions_dispatch.dispatchPlannerPlanToScout;
const workspaceMissionDispatchScoutReportToBuilder = features.missions_dispatch.dispatchScoutReportToBuilder;
const workspaceMissionDispatchBuilderReportToReviewer = features.missions_dispatch.dispatchBuilderReportToReviewer;
const workspaceMissionDispatchReviewerReportToExecutor = features.missions_dispatch.dispatchReviewerReportToExecutor;
const workspaceMissionDispatchExecutorReportToPilot = features.missions_dispatch.dispatchExecutorReportToPilot;

const missionCapturePilotOperationalBrief = features.missions_capture.capturePilotBrief;
const missionCapturePlannerOperationalPlan = features.missions_capture.capturePlannerPlan;
const missionCaptureScoutReport = features.missions_capture.captureScoutReport;
const missionCaptureBuilderImplementationReport = features.missions_capture.captureBuilderReport;
const missionCaptureReviewerReviewReport = features.missions_capture.captureReviewerReport;
const missionCaptureExecutorVerificationReport = features.missions_capture.captureExecutorReport;
const missionCapturePilotDeliveryReport = features.missions_capture.capturePilotDeliveryReport;

const missionFinalizeFromPilotDeliveryReport = features.missions.finalize;
const missionRunNextStep = features.missions.runNextStep;

const missions = features.missions.index;
const missionNew = features.missions.newForm;
const missionCreate = features.missions.create;
const missionShow = features.missions.show;
const missionEdit = features.missions.edit;
const missionUpdate = features.missions.update;
const missionDelete = features.missions.delete;

const agents = features.agents.index;
const agentNew = features.agents.newForm;
const agentCreate = features.agents.create;
const agentShow = features.agents.show;
const agentEdit = features.agents.edit;
const agentUpdate = features.agents.update;
const agentDelete = features.agents.delete;

const squads = features.squads.index;
const squadNew = features.squads.newForm;
const squadCreate = features.squads.create;
const squadShow = features.squads.show;
const squadEdit = features.squads.edit;
const squadUpdate = features.squads.update;
const squadDelete = features.squads.delete;

const providers = features.providers.index;
const providerNew = features.providers.newForm;
const providerCreate = features.providers.create;
const providerShow = features.providers.show;
const providerEdit = features.providers.edit;
const providerUpdate = features.providers.update;
const providerDelete = features.providers.delete;
const providerModelNew = features.providers.modelNewForm;
const providerModelCreate = features.providers.modelCreate;
const providerModelEdit = features.providers.modelEdit;
const providerModelUpdate = features.providers.modelUpdate;
const providerModelDelete = features.providers.modelDelete;

const stacks = features.stacks.index;
const stackNew = features.stacks.newForm;
const stackCreate = features.stacks.create;
const stackEdit = features.stacks.edit;
const stackUpdate = features.stacks.update;
const stackDelete = features.stacks.delete;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    try db.init(arena, io, .{
        .host = spider.env.getOr("PG_HOST", "127.0.0.1"),
        .port = spider.env.getInt(u16, "PG_PORT", 55432),
        .user = spider.env.getOr("PG_USER", "zivyar"),
        .password = spider.env.getOr("PG_PASSWORD", "zivyar_dev_password"),
        .database = spider.env.getOr("PG_DB", "zivyar_cockpit"),
    });
    defer db.deinit();

    var server = spider.server();
    defer server.deinit();

    server
        .get("/", dashboard)
        .get("/workspaces", workspaces)
        .get("/graphify", graphifyIndex)
        .get("/workspaces/new", workspaceNew)
        .post("/workspaces", workspaceCreate)
        .get("/workspaces/:id/edit", workspaceEdit)
        .post("/workspaces/:id/update", workspaceUpdate)
        .post("/workspaces/:id/local-path/confirm", workspaceConfirmLocalPathChange)
        .post("/workspaces/:id/delete", workspaceDelete)
        .get("/workspaces/:id/graphify", workspaceGraphifyShow)
        .post("/workspaces/:id/memory", workspaceMemoryCreate)
        .post("/workspaces/:id/memory/:entry_id/update", workspaceMemoryUpdate)
        .post("/workspaces/:id/memory/:entry_id/delete", workspaceMemoryDelete)
        .post("/workspaces/:id/handoffs", workspaceHandoffCreate)
        .post("/workspaces/:id/handoffs/:entry_id/update", workspaceHandoffUpdate)
        .post("/workspaces/:id/handoffs/:entry_id/delete", workspaceHandoffDelete)
        .post("/workspaces/:id/decision-records", workspaceDecisionRecordCreate)
        .post("/workspaces/:id/decision-records/:entry_id/update", workspaceDecisionRecordUpdate)
        .post("/workspaces/:id/decision-records/:entry_id/delete", workspaceDecisionRecordDelete)
        .post("/workspaces/:id/snapshots", workspaceSnapshotCreate)
        .post("/workspaces/:id/snapshots/:entry_id/update", workspaceSnapshotUpdate)
        .post("/workspaces/:id/snapshots/:entry_id/delete", workspaceSnapshotDelete)
        .post("/workspaces/:id/runtime/prepare", workspaceRuntimePrepare)
        .post("/workspaces/:id/runtime/start", workspaceRuntimeStart)
        .post("/workspaces/:id/runtime/stop", workspaceRuntimeStop)
        .get("/workspaces/:id/runtime/live", workspaceRuntimeLiveStatus)
        .post("/workspaces/:id/panes/:pane_id/session/open", workspacePaneOpenSession)
        .post("/workspaces/:id/panes/:pane_id/session/close", workspacePaneCloseSession)
        .post("/workspaces/:id/panes/:pane_id/session/resume", workspacePaneResumeSession)
        .post("/workspaces/:id/panes/:pane_id/session/recreate", workspacePaneRecreateSession)
        .post("/workspaces/:id/missions/:mission_id/activate", workspaceMissionActivate)
        .post("/workspaces/:id/missions/:mission_id/dispatch/pilot", workspaceMissionDispatchToPilot)
        .post("/workspaces/:id/missions/:mission_id/dispatch/planner", workspaceMissionDispatchPilotBriefToPlanner)
        .post("/workspaces/:id/missions/:mission_id/dispatch/scout", workspaceMissionDispatchPlannerPlanToScout)
        .post("/workspaces/:id/missions/:mission_id/dispatch/builder", workspaceMissionDispatchScoutReportToBuilder)
        .post("/workspaces/:id/missions/:mission_id/dispatch/reviewer", workspaceMissionDispatchBuilderReportToReviewer)
        .post("/workspaces/:id/missions/:mission_id/dispatch/executor", workspaceMissionDispatchReviewerReportToExecutor)
        .post("/workspaces/:id/missions/:mission_id/dispatch/pilot-delivery", workspaceMissionDispatchExecutorReportToPilot)
        .post("/missions/:id/capture/pilot-brief", missionCapturePilotOperationalBrief)
        .post("/missions/:id/capture/planner-plan", missionCapturePlannerOperationalPlan)
        .post("/missions/:id/capture/scout-report", missionCaptureScoutReport)
        .post("/missions/:id/capture/builder-report", missionCaptureBuilderImplementationReport)
        .post("/missions/:id/capture/reviewer-report", missionCaptureReviewerReviewReport)
        .post("/missions/:id/capture/executor-report", missionCaptureExecutorVerificationReport)
        .post("/missions/:id/capture/pilot-delivery-report", missionCapturePilotDeliveryReport)
        .post("/missions/:id/finalize", missionFinalizeFromPilotDeliveryReport)
        .post("/missions/:id/next-step", missionRunNextStep)
        .get("/workspaces/:id", workspaceShow)
        .get("/missions", missions)
        .get("/missions/new", missionNew)
        .post("/missions", missionCreate)
        .get("/missions/:id", missionShow)
        .get("/missions/:id/edit", missionEdit)
        .post("/missions/:id/update", missionUpdate)
        .post("/missions/:id/delete", missionDelete)
        .get("/agents", agents)
        .get("/agents/new", agentNew)
        .post("/agents", agentCreate)
        .get("/agents/:id", agentShow)
        .get("/agents/:id/edit", agentEdit)
        .post("/agents/:id/update", agentUpdate)
        .post("/agents/:id/delete", agentDelete)
        .get("/squads", squads)
        .get("/squads/new", squadNew)
        .post("/squads", squadCreate)
        .get("/squads/:id", squadShow)
        .get("/squads/:id/edit", squadEdit)
        .post("/squads/:id/update", squadUpdate)
        .post("/squads/:id/delete", squadDelete)
        .get("/providers", providers)
        .get("/providers/new", providerNew)
        .post("/providers", providerCreate)
        .get("/providers/:id", providerShow)
        .get("/providers/:id/edit", providerEdit)
        .post("/providers/:id/update", providerUpdate)
        .post("/providers/:id/delete", providerDelete)
        .get("/providers/:id/models/new", providerModelNew)
        .post("/providers/:id/models", providerModelCreate)
        .get("/providers/:id/models/:model_id/edit", providerModelEdit)
        .post("/providers/:id/models/:model_id/update", providerModelUpdate)
        .post("/providers/:id/models/:model_id/delete", providerModelDelete)
        .get("/stacks", stacks)
        .get("/stacks/new", stackNew)
        .post("/stacks", stackCreate)
        .get("/stacks/:id/edit", stackEdit)
        .post("/stacks/:id/update", stackUpdate)
        .post("/stacks/:id/delete", stackDelete)
        .listen(.{}) catch {};
}
