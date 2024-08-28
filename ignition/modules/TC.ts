import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const ceth = buildModule("CETH", (m) => {
  const contract = m.contract("CETH");
  return { ceth: contract };
});

export const cst = buildModule("CST", (m) => {
  const _name = m.getParameter("name");
  const _symbol = m.getParameter("symbol");
  const _ceth = m.getParameter("ceth");
  const _admin = m.getParameter("admin");

  const contract = m.contract("CST", [_name, _symbol, _ceth, _admin]);
  return { cst: contract };
});
