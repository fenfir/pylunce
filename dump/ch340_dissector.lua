local control = Proto("ch340.ctl", "CH340 Serial Control")
local bulk = Proto("ch340.bulk", "CH340 Serial Data")

local ep_dir_f = Field.new("usb.endpoint_address.direction")

local REQ_TBL = {
  [0x5F] = "CH341_REQ_READ_VERSION",
  [0x9A] = "CH341_REQ_WRITE_REG",
  [0x95] = "CH341_REQ_READ_REG",
  [0xA1] = "CH341_REQ_SERIAL_INIT",
  [0xA4] = "CH341_REQ_MODEM_CTRL",
}

local REG_TBL = {
  [0x07] = "STATUS2",
  [0x06] = "STATUS",
  [0x13] = "DIVISOR",
  [0x12] = "PRESCALER",
  [0x18] = "LCR",
  [0x25] = "LCR2",
}

control.fields.req = ProtoField.uint8("ch340.ctl.req", "Request", base.HEX, REQ_TBL)
control.fields.reg1 = ProtoField.uint8("ch340.ctl.reg1", "Register 1", base.HEX, REG_TBL)
control.fields.reg2 = ProtoField.uint8("ch340.ctl.reg2", "Register 2", base.HEX, REG_TBL)
control.fields.val1 = ProtoField.uint8("ch340.ctl.val1", "Value 1", base.HEX)
control.fields.val2 = ProtoField.uint8("ch340.ctl.val2", "Value 2", base.HEX)
control.fields.modem = ProtoField.uint8("ch340.ctl.modem", "Modem", base.HEX)

bulk.fields.data_in = ProtoField.bytes("ch340.bulk.data_in", "Data In")
bulk.fields.data_out = ProtoField.bytes("ch340.bulk.data_out", "Data Out")

pcall(DissectorTable.heuristic_new, "ch340.serial_data", bulk)

function control.dissector(buffer, pinfo, tree)
  if buffer:captured_len() < 1 then return end

  local sub = tree:add(control, buffer())

  local req = buffer(0, 1)
  sub:add(control.fields.req, req)

  req = REQ_TBL[req:uint()] or ""
  pinfo.cols.info:set("CH340 " .. req:sub(11))
  if req == "CH341_REQ_WRITE_REG" or
     req == "CH341_REQ_READ_REG" then

    local reg2 = buffer(1, 1)
    local reg1 = buffer(2, 1)
    sub:add(control.fields.reg1, reg1)
    sub:add(control.fields.reg2, reg2)

    reg1 = reg1:uint()
    reg2 = reg2:uint()

    pinfo.cols.info:append(string.format(" %s/%s", (REG_TBL[reg1] or reg1), (REG_TBL[reg2] or reg2)))

    if req == "CH341_REQ_WRITE_REG" then
      local val2 = buffer(3, 1)
      local val1 = buffer(4, 1)
      sub:add(control.fields.val1, val1)
      sub:add(control.fields.val2, val2)
    end
  elseif name == "CH341_REQ_MODEM_CTRL" then
    sub:add(control.fields.modem, buffer(1))
  end
end

function bulk.dissector(buffer, pinfo, tree)
  if buffer:captured_len() < 1 then return end

  local sub = tree:add(bulk, buffer())
  pinfo.cols.info:set("CH340 Serial")

  local ep_dir = ep_dir_f()() -- 0: h2d, 1: d2h
  if ep_dir == 0 then
    pinfo.cols.info:append(" out")
    pinfo.p2p_dir = P2P_DIR_SENT
    sub:add(bulk.fields.data_out, buffer())
  else
    pinfo.cols.info:append(" in")
    pinfo.p2p_dir = P2P_DIR_RECV
    sub:add(bulk.fields.data_in, buffer())
  end

  DissectorTable.try_heuristics("ch340.serial_data", buffer, pinfo, tree)
end

function usb_protocol_key(class, subclass, protocol)
  return bit.bor(
    bit.lshift(1, 31),
    bit.lshift(bit.band(class, 0xff), 16),
    bit.lshift(bit.band(subclass, 0xff), 8),
    bit.band(protocol, 0xff)
  )
end

local ctl_table = DissectorTable.get("usb.control")
ctl_table:add(usb_protocol_key(0xff, 0x01, 0x02), control)
ctl_table:add(0xffff, control)

local bulk_table = DissectorTable.get("usb.bulk")
bulk_table:add(usb_protocol_key(0xff, 0x01, 0x02), bulk)
bulk_table:add(0xffff, bulk)